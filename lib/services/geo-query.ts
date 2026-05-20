// Orchestration Service: Geo Query Intelligence
// Unified API that combines all data sources into single query response

import { gbifClient } from './gbif';
import { soilGridsClient } from './soil-grids';
import { firmsClient } from './nasa-firms';
import { copernicusClient } from './copernicus-cds';
import { epaECHOClient } from './epa-echo';
import type {
  GeoQueryRequest,
  GeoQueryResponse,
  AttributionSource,
  Species,
  ClimateSignal,
  DisturbanceEvent,
  ComplianceRule,
  Ecoregion,
} from '@/lib/types';

interface DataSourceAttribution {
  name: string;
  license: string;
  commercialUseAllowed: boolean;
  attributionText: string;
  url: string;
}

const DATA_SOURCE_ATTRIBUTIONS: Record<string, DataSourceAttribution> = {
  GBIF: {
    name: 'GBIF',
    license: 'CC-BY / CC0 (varies by record)',
    commercialUseAllowed: true,
    attributionText: 'Global Biodiversity Information Facility',
    url: 'https://www.gbif.org',
  },
  SoilGrids: {
    name: 'SoilGrids v2.0',
    license: 'CC-BY 4.0',
    commercialUseAllowed: true,
    attributionText: 'ISRIC - World Soil Information',
    url: 'https://www.isric.org',
  },
  NASA_FIRMS: {
    name: 'NASA FIRMS',
    license: 'Public Domain',
    commercialUseAllowed: true,
    attributionText: 'NASA Goddard Space Flight Center',
    url: 'https://firms.modaps.eosdis.nasa.gov',
  },
  ERA5: {
    name: 'ERA5 (Copernicus)',
    license: 'Free tier / Copernicus',
    commercialUseAllowed: true,
    attributionText: 'ECMWF / Copernicus Climate Data Store',
    url: 'https://cds.climate.copernicus.eu',
  },
  EPA_ECHO: {
    name: 'EPA ECHO',
    license: 'Public Domain',
    commercialUseAllowed: true,
    attributionText: 'US Environmental Protection Agency',
    url: 'https://echo.epa.gov',
  },
};

export class GeoQueryService {
  private usedSources: Set<string> = new Set();

  /**
   * Main geo query: comprehensive nature intelligence for any coordinate
   */
  async queryLocation(request: GeoQueryRequest): Promise<GeoQueryResponse> {
    const startTime = Date.now();

    try {
      // Reset source tracking
      this.usedSources.clear();

      // Execute all queries in parallel (with timeout/fallback handling)
      const [biodiversity, soil, climate, disturbances, regulations, ecoregion] =
        await Promise.allSettled([
          this.queryBiodiversity(request),
          this.querySoil(request),
          this.queryClimate(request),
          this.queryDisturbances(request),
          this.queryRegulations(request),
          this.queryEcoregion(request),
        ]);

      // Build response
      const response: GeoQueryResponse = {
        latitude: request.latitude,
        longitude: request.longitude,
        ecoregion: ecoregion.status === 'fulfilled' ? ecoregion.value : undefined,
        biodiversity:
          biodiversity.status === 'fulfilled'
            ? biodiversity.value
            : { species: [], totalRecords: 0 },
        climate:
          climate.status === 'fulfilled'
            ? climate.value
            : { current: [], projections: [] },
        soil: soil.status === 'fulfilled' ? soil.value : [],
        disturbances:
          disturbances.status === 'fulfilled' ? disturbances.value : [],
        regulations:
          regulations.status === 'fulfilled' ? regulations.value : [],
        attribution: {
          sources: this.buildAttributionChain(),
          generatedAt: new Date().toISOString(),
          queryId: `query-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        },
      };

      console.log(`Geo query completed in ${Date.now() - startTime}ms`);
      return response;
    } catch (error) {
      console.error('Geo query failed:', error);
      throw error;
    }
  }

  /**
   * Query biodiversity: species occurrences from GBIF
   */
  private async queryBiodiversity(request: GeoQueryRequest): Promise<{
    species: Species[];
    totalRecords: number;
  }> {
    this.usedSources.add('GBIF');

    const result = await gbifClient.searchOccurrences({
      latitude: request.latitude,
      longitude: request.longitude,
      radiusKm: request.radiusKm || 50,
      limit: 50,
    });

    // Extract unique species
    const speciesMap = new Map<string, Species>();
    for (const occ of result.occurrences) {
      if (!speciesMap.has(occ.speciesId)) {
        // Would fetch full species data from database
        speciesMap.set(occ.speciesId, {
          id: occ.speciesId,
          scientificName: 'Unknown',
          kingdom: 'Animalia',
          sourceId: 'gbif',
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }
    }

    return {
      species: Array.from(speciesMap.values()),
      totalRecords: result.total,
    };
  }

  /**
   * Query soil: 14 properties from SoilGrids
   */
  private async querySoil(request: GeoQueryRequest) {
    this.usedSources.add('SoilGrids');

    const profile = await soilGridsClient.queryPoint(request.latitude, request.longitude);
    return profile ? [profile] : [];
  }

  /**
   * Query climate: current + projections
   */
  private async queryClimate(request: GeoQueryRequest) {
    this.usedSources.add('ERA5');

    // Query current climate (last 30 days average)
    const endDate = new Date();
    const startDate = new Date(endDate.getTime() - 30 * 24 * 60 * 60 * 1000);

    try {
      const current = await copernicusClient.queryERA5({
        latitude: request.latitude,
        longitude: request.longitude,
        variable: ['2m_temperature', 'total_precipitation'],
        dateStart: startDate.toISOString().split('T')[0],
        dateEnd: endDate.toISOString().split('T')[0],
      });

      // TODO: Query climate projections from WorldClim/CHELSA
      const projections = [];

      return { current, projections };
    } catch (error) {
      console.warn('Climate query failed:', error);
      return { current: [], projections: [] };
    }
  }

  /**
   * Query disturbances: recent fires from NASA FIRMS
   */
  private async queryDisturbances(request: GeoQueryRequest): Promise<DisturbanceEvent[]> {
    this.usedSources.add('NASA_FIRMS');

    const fires = await firmsClient.queryActiveFires({
      latitude: request.latitude,
      longitude: request.longitude,
      radiusKm: request.radiusKm || 50,
      daysBack: 30,
    });

    return fires;
  }

  /**
   * Query regulations: EPA compliance rules for USA locations
   */
  private async queryRegulations(request: GeoQueryRequest): Promise<ComplianceRule[]> {
    this.usedSources.add('EPA_ECHO');

    // Only for US locations
    if (request.longitude < -130 || request.longitude > -65 || request.latitude < 25 || request.latitude > 49) {
      return [];
    }

    const facilities = await epaECHOClient.searchFacilities({
      latitude: request.latitude,
      longitude: request.longitude,
      radiusKm: request.radiusKm || 50,
    });

    // Transform facilities to compliance rules
    return facilities
      .map((fac) => ({
        id: `epa-${fac.RegistryId}`,
        regulationId: 'epa-base',
        activityType: 'logging' as const,
        ruleType: 'permit_required' as const,
        conditions: {
          facilityName: fac.FacilityName,
          complianceStatus: epaECHOClient['getComplianceSummary'](fac),
        },
        description: `Facility: ${fac.FacilityName}`,
        permitRequired: true,
      }))
      .slice(0, 10); // Limit to top 10
  }

  /**
   * Query ecoregion: WWF ecoregion at location
   */
  private async queryEcoregion(request: GeoQueryRequest): Promise<Ecoregion | undefined> {
    // TODO: Query spatial database for ecoregion at lat/lon
    return undefined;
  }

  /**
   * Build complete attribution chain for used sources
   */
  private buildAttributionChain(): AttributionSource[] {
    const sources: AttributionSource[] = [];

    for (const sourceName of this.usedSources) {
      const attr = DATA_SOURCE_ATTRIBUTIONS[sourceName];
      if (attr) {
        sources.push({
          name: attr.name,
          license: attr.license,
          attributionText: attr.attributionText,
          url: attr.url,
          commercialUseAllowed: attr.commercialUseAllowed,
        });
      }
    }

    return sources;
  }
}

export const geoQueryService = new GeoQueryService();
