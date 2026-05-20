// Core TypeScript Types for TerraWeb

import type { Geometry } from 'geojson';

// ============================================================================
// DATA SOURCE TYPES
// ============================================================================

export interface DataSource {
  id: string;
  name: string;
  provider: string;
  domain: 'biodiversity' | 'climate' | 'soil' | 'hydrology' | 'regulation' | 'carbon' | 'fire';
  spatialCoverage: 'global' | 'regional' | 'national' | 'local';
  temporalCoverage: {
    start: string;
    end: string;
  };
  updateFrequency: 'daily' | 'weekly' | 'monthly' | 'annual' | 'never';
  accessMethod: 'api' | 'download' | 'wms' | 'wcs' | 'wfs' | 'database';
  baseUrl?: string;
  documentationUrl?: string;
  apiKeyRequired: boolean;
  license: string;
  licenseUrl?: string;
  commercialUseAllowed: boolean;
  commercialUseNotes?: string;
  attributionRequired: boolean;
  attributionText?: string;
  qualityScore: number; // 0.00-1.00
  notes: string;
  createdAt: Date;
  updatedAt: Date;
}

// ============================================================================
// SPECIES TYPES
// ============================================================================

export interface Species {
  id: string;
  scientificName: string;
  commonNames?: Record<string, string>;
  kingdom: 'Animalia' | 'Plantae' | 'Fungi' | 'Bacteria' | 'Archaea';
  phylum?: string;
  class?: string;
  order?: string;
  family?: string;
  genus?: string;
  speciesEpithet?: string;
  subspecies?: string;
  taxonRank: 'species' | 'subspecies' | 'variety' | 'form';
  gbifKey?: number;
  inatId?: number;
  wfoId?: string;
  mycobanId?: number;
  boldBin?: string;
  iucnStatus?: 'LC' | 'NT' | 'VU' | 'EN' | 'CR' | 'EW' | 'EX';
  nativeRanges?: string[];
  introducedRanges?: string[];
  invasiveStatus?: 'none' | 'watch' | 'invasive' | 'highly_invasive';
  sourceId: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface SpeciesTraits {
  id: string;
  speciesId: string;
  shadeToLerance?: 'very_low' | 'low' | 'moderate' | 'high' | 'very_high';
  droughtTolerance?: 'very_low' | 'low' | 'moderate' | 'high' | 'very_high';
  floodTolerance?: 'very_low' | 'low' | 'moderate' | 'high' | 'very_high';
  frostTolerance?: 'very_low' | 'low' | 'moderate' | 'high' | 'very_high';
  saltTolerance?: 'very_low' | 'low' | 'moderate' | 'high' | 'very_high';
  tempMinC?: number;
  tempMaxC?: number;
  tempOptimalC?: number;
  precipMinMm?: number;
  precipMaxMm?: number;
  soilPhMin?: number;
  soilPhMax?: number;
  soilTexturePreference?: ('clay' | 'loam' | 'sand' | 'silt' | 'peat')[];
  elevationMinM?: number;
  elevationMaxM?: number;
  maxHeightM?: number;
  growthRateCmPerYear?: number;
  lifespanYears?: number;
  crownShape?: string;
  rootingDepthM?: number;
  woodDensityGCm3?: number;
  leafType?: 'broadleaf' | 'needle' | 'scale' | 'grass';
  phenology?: 'evergreen' | 'deciduous' | 'semi_deciduous' | 'drought_deciduous';
  nitrogenFixing: boolean;
  mycorrhizalType?: 'AM' | 'ECM' | 'ERM' | 'ericoid' | 'orchid' | 'none';
  pollinatorDependence?: 'obligate' | 'facultative' | 'none';
  pollinatorTypes?: string[];
  seedDispersalMode?: ('wind' | 'water' | 'animal' | 'gravity' | 'explosive')[];
  fireResponse?: 'resprouter' | 'obligate_seeder' | 'fire_sensitive' | 'fire_adapted';
  carbonSequestrationRateKgYr?: number;
  erosionControlPotential?: 'very_low' | 'low' | 'moderate' | 'high' | 'very_high';
  confidenceScore: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface SpeciesUse {
  id: string;
  speciesId: string;
  useCategory: 'timber' | 'food' | 'medicine' | 'ornamental' | 'fiber' | 'fuel' | 'fodder' | 'cultural' | 'dye' | 'tannin';
  description?: string;
  quality?: 'excellent' | 'good' | 'moderate' | 'poor';
  sector?: string;
  commercialAvailability?: 'widely_available' | 'limited' | 'rare' | 'extinct_in_wild';
  tradeRestrictions?: string;
  marketValueUsdPerUnit?: number;
}

export interface SpeciesOccurrence {
  id: string;
  speciesId: string;
  latitude: number;
  longitude: number;
  observationDate?: string;
  observationType: 'specimen' | 'human_observation' | 'camera_trap' | 'acoustic' | 'eDNA' | 'machine_learning';
  source: 'GBIF' | 'iNaturalist' | 'eBird' | 'OBIS' | 'field_survey' | 'herbarium';
  sourceRecordId?: string;
  confidenceScore: number;
  license: string;
  attribution?: string;
  createdAt: Date;
}

// ============================================================================
// CLIMATE TYPES
// ============================================================================

export interface ClimateSignal {
  id: string;
  latitude: number;
  longitude: number;
  metric: 'temperature' | 'precipitation' | 'ndvi' | 'fire_risk' | 'drought_severity' | 'wind_speed' | 'humidity';
  subMetric?: 'min' | 'max' | 'mean' | 'std' | 'percentile_90';
  period: 'daily' | 'dekadal' | 'monthly' | 'annual';
  timeStart: string;
  timeEnd?: string;
  value: number;
  unit: string;
  source: string;
  confidenceScore: number;
  createdAt: Date;
}

export interface ClimateProjection {
  speciesId: string;
  ecoregionId: string;
  scenario: 'current' | 'SSP1-1.9' | 'SSP1-2.6' | 'SSP2-4.5' | 'SSP3-7.0' | 'SSP5-8.5';
  timeHorizon: 2030 | 2050 | 2070 | 2100;
  suitabilityScore: number; // 0-1
  riskFactors: Record<string, number>;
  modelType: 'maxent' | 'random_forest' | 'ensemble' | 'sdm';
}

// ============================================================================
// SOIL TYPES
// ============================================================================

export interface SoilProfile {
  id: string;
  latitude: number;
  longitude: number;
  depthCmStart: number;
  depthCmEnd: number;
  phWater?: number;
  organicCarbonGKg?: number;
  totalNitrogenGKg?: number;
  clayPercent?: number;
  siltPercent?: number;
  sandPercent?: number;
  bulkDensityKgM3?: number;
  waterContentFieldCapacityPercent?: number;
  source: 'SoilGrids' | 'USDA_NRCS' | 'field_survey' | 'literature';
  confidenceScore: number;
  createdAt: Date;
}

// ============================================================================
// REGULATION TYPES
// ============================================================================

export interface Regulation {
  id: string;
  name: string;
  regulationType: 'environmental_law' | 'forestry_code' | 'water_law' | 'protected_area_rule' | 'ESG_standard';
  jurisdiction: string;
  jurisdictionalScope: 'national' | 'regional' | 'local' | 'protected_area';
  effectiveFrom?: string;
  effectiveTo?: string;
  authorityAgency: string;
  referenceUrl?: string;
  summary: string;
  applicableSectors: string[];
  createdAt: Date;
}

export interface ComplianceRule {
  id: string;
  regulationId: string;
  activityType: 'logging' | 'land_clearing' | 'planting' | 'discharge' | 'construction' | 'mining' | 'dredging' | 'water_extraction';
  ruleType: 'prohibition' | 'restriction' | 'requirement' | 'permit_required' | 'best_practice';
  conditions: Record<string, unknown>;
  description: string;
  penaltyDescription?: string;
  permitRequired: boolean;
}

// ============================================================================
// DISTURBANCE TYPES
// ============================================================================

export interface DisturbanceEvent {
  id: string;
  eventType: 'fire' | 'flood' | 'drought' | 'storm' | 'pest_outbreak' | 'disease' | 'landslide' | 'logging' | 'mining';
  startDate: string;
  endDate?: string;
  severity: 'low' | 'moderate' | 'high' | 'extreme';
  affectedAreaHa: number;
  latitude: number;
  longitude: number;
  radius?: number;
  source: 'NASA_FIRMS' | 'Sentinel-2' | 'field_report' | 'USGS';
  createdAt: Date;
  detectedAt?: Date;
}

// ============================================================================
// ECOREGION TYPES
// ============================================================================

export interface Ecoregion {
  id: string;
  code: string;
  name: string;
  biome: string;
  realm: string;
  areaSqKm: number;
  climateProfile?: Record<string, unknown>;
  soilProfile?: Record<string, unknown>;
  typicalDisturbance?: string[];
}

// ============================================================================
// REFORESTATION TYPES
// ============================================================================

export interface SpeciesMix {
  speciesId: string;
  proportion: number;
  densityPerHa: number;
  spacingM?: number;
}

export interface ReforestationRecipe {
  id: string;
  name: string;
  description?: string;
  targetEcoregionId: string;
  targetObjective: 'biodiversity' | 'carbon' | 'water_protection' | 'timber' | 'agroforestry' | 'food_production';
  climateScenario?: 'current' | 'SSP1-2.6' | 'SSP2-4.5' | 'SSP5-8.5';
  timeHorizon?: number;
  speciesMix: SpeciesMix[];
  totalDensityPerHa: number;
  plantingPattern: 'random' | 'cluster' | 'row' | 'block';
  successionPlan?: Array<{
    phase: number;
    yearRange: string;
    speciesMix: SpeciesMix[];
    management: string;
  }>;
  constraintsAddressed?: Record<string, unknown>;
  establishmentYears: number;
  carbonSequestration20yrTonsHa: number;
  legalRequirements?: string;
  estimatedCostUsdPerHa?: number;
  createdAt: Date;
}

// ============================================================================
// GEO QUERY TYPES
// ============================================================================

export interface GeoQueryRequest {
  latitude: number;
  longitude: number;
  radiusKm?: number;
  depth?: 'quick' | 'full';
  filters?: {
    speciesKingdom?: 'Animalia' | 'Plantae' | 'Fungi' | 'Bacteria';
    iucnStatus?: string;
    climateScenario?: string;
  };
}

export interface AttributionSource {
  name: string;
  license: string;
  attributionText: string;
  url: string;
  commercialUseAllowed: boolean;
  commercialUseNotes?: string;
}

export interface GeoQueryResponse {
  latitude: number;
  longitude: number;
  ecoregion?: Ecoregion;
  biodiversity: {
    species: Species[];
    totalRecords: number;
  };
  climate: {
    current: ClimateSignal[];
    projections: ClimateProjection[];
  };
  soil: SoilProfile[];
  disturbances: DisturbanceEvent[];
  regulations: ComplianceRule[];
  attribution: {
    sources: AttributionSource[];
    generatedAt: string;
    queryId: string;
  };
}

// ============================================================================
// API RESPONSE TYPES
// ============================================================================

export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
  };
  attribution?: {
    sources: AttributionSource[];
  };
}

export type { Geometry };
