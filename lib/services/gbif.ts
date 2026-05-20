// GBIF API Client
// Accesses 3B+ species occurrence records (CC-BY/CC0)

import axios, { AxiosInstance } from 'axios';
import type { Species, SpeciesOccurrence, ApiResponse } from '@/lib/types';

const GBIF_BASE_URL = 'https://api.gbif.org/v1';

export class GBIFClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: GBIF_BASE_URL,
      timeout: 30000,
      headers: {
        'User-Agent': 'TerraWeb/1.0 (nature-intelligence-platform)',
      },
    });
  }

  /**
   * Search for species by name
   * Returns up to 100 results
   */
  async searchSpecies(query: string): Promise<Species[]> {
    try {
      const response = await this.client.get('/species/search', {
        params: {
          q: query,
          limit: 100,
        },
      });

      return response.data.results?.map((record: any) => ({
        id: `gbif-${record.key}`,
        scientificName: record.scientificName,
        kingdom: record.kingdom,
        phylum: record.phylum,
        class: record.class,
        order: record.order,
        family: record.family,
        genus: record.genus,
        gbifKey: record.key,
        iucnStatus: record.threatStatuses?.[0]?.status,
        sourceId: 'gbif',
        createdAt: new Date(),
        updatedAt: new Date(),
      })) || [];
    } catch (error) {
      console.error('GBIF species search failed:', error);
      return [];
    }
  }

  /**
   * Get species details by GBIF key
   */
  async getSpeciesDetail(gbifKey: number): Promise<Species | null> {
    try {
      const response = await this.client.get(`/species/${gbifKey}`);
      const record = response.data;

      return {
        id: `gbif-${record.key}`,
        scientificName: record.scientificName,
        commonNames: record.commonNames || {},
        kingdom: record.kingdom,
        phylum: record.phylum,
        class: record.class,
        order: record.order,
        family: record.family,
        genus: record.genus,
        gbifKey: record.key,
        iucnStatus: record.threatStatuses?.[0]?.status,
        sourceId: 'gbif',
        createdAt: new Date(),
        updatedAt: new Date(),
      };
    } catch (error) {
      console.error(`Failed to fetch GBIF species ${gbifKey}:`, error);
      return null;
    }
  }

  /**
   * Search occurrences by location (lat/lon) or species key
   * Returns paginated results (default 100 per page, max 300)
   */
  async searchOccurrences(params: {
    latitude?: number;
    longitude?: number;
    radiusKm?: number;
    speciesKey?: number;
    limit?: number;
    offset?: number;
  }): Promise<{ occurrences: SpeciesOccurrence[]; total: number }> {
    try {
      const gbifParams: Record<string, any> = {
        limit: Math.min(params.limit || 100, 300),
        offset: params.offset || 0,
      };

      if (params.latitude && params.longitude) {
        const radiusKm = params.radiusKm || 50;
        gbifParams.decimalLatitude = params.latitude;
        gbifParams.decimalLongitude = params.longitude;
        gbifParams.geoDistance = radiusKm;
      }

      if (params.speciesKey) {
        gbifParams.speciesKey = params.speciesKey;
      }

      const response = await this.client.get('/occurrence/search', {
        params: gbifParams,
      });

      const occurrences = response.data.results?.map((record: any) => ({
        id: `gbif-occ-${record.key}`,
        speciesId: `gbif-${record.speciesKey}`,
        latitude: record.decimalLatitude,
        longitude: record.decimalLongitude,
        observationDate: record.eventDate,
        observationType: 'human_observation' as const,
        source: 'GBIF' as const,
        sourceRecordId: record.key.toString(),
        confidenceScore: record.coordinateUncertaintyInMeters ? 0.85 : 0.95,
        license: record.license || 'CC-BY',
        attribution: record.publisherTitle,
        createdAt: new Date(record.eventDate || record.modified),
      })) || [];

      return {
        occurrences,
        total: response.data.count || 0,
      };
    } catch (error) {
      console.error('GBIF occurrence search failed:', error);
      return { occurrences: [], total: 0 };
    }
  }

  /**
   * Stream large occurrence datasets
   * Useful for batch ingestion
   */
  async streamOccurrences(params: {
    speciesKey?: number;
    latitude?: number;
    longitude?: number;
    radiusKm?: number;
  }): AsyncGenerator<SpeciesOccurrence[]> {
    const limit = 300;
    let offset = 0;
    let hasMore = true;

    while (hasMore) {
      const result = await this.searchOccurrences({
        ...params,
        limit,
        offset,
      });

      if (result.occurrences.length === 0) {
        hasMore = false;
      } else {
        yield result.occurrences;
        offset += limit;
      }
    }
  }

  /**
   * Get statistics for a species
   */
  async getSpeciesStats(gbifKey: number): Promise<{
    occurrenceCount: number;
    countries: { country: string; count: number }[];
  }> {
    try {
      const response = await this.client.get(
        `/occurrence/search?speciesKey=${gbifKey}&facet=COUNTRY&limit=0`
      );

      return {
        occurrenceCount: response.data.count || 0,
        countries: response.data.facets?.[0]?.counts?.map((c: any) => ({
          country: c.name,
          count: c.count,
        })) || [],
      };
    } catch (error) {
      console.error('Failed to fetch species stats:', error);
      return { occurrenceCount: 0, countries: [] };
    }
  }
}

// Export singleton instance
export const gbifClient = new GBIFClient();
