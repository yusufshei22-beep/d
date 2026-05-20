-- TerraWeb Database Schema (PostgreSQL + PostGIS)
-- Comprehensive nature intelligence layer

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================================
-- DATA SOURCE REGISTRY (tracks all external data sources)
-- ============================================================================

CREATE TABLE data_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  provider TEXT NOT NULL,
  domain TEXT NOT NULL, -- biodiversity, climate, soil, hydrology, regulation, carbon, fire
  spatial_coverage TEXT NOT NULL, -- global, regional, national
  temporal_coverage JSONB NOT NULL, -- {start: "1940", end: "present"}
  update_frequency TEXT NOT NULL, -- daily, weekly, monthly, annual, never
  access_method TEXT NOT NULL, -- api, download, wms, wcs, wfs, database
  base_url TEXT,
  documentation_url TEXT,
  api_key_required BOOLEAN DEFAULT false,
  license TEXT NOT NULL,
  license_url TEXT,
  commercial_use_allowed BOOLEAN DEFAULT false,
  commercial_use_notes TEXT,
  attribution_required BOOLEAN DEFAULT true,
  attribution_text TEXT,
  quality_score NUMERIC(3,2) CHECK (quality_score >= 0 AND quality_score <= 1), -- 0.00-1.00
  schema_mapping JSONB, -- maps source fields to our canonical schema
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  data_freshness_days INTEGER,
  contact_email TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_data_sources_domain ON data_sources(domain);
CREATE INDEX idx_data_sources_commercial ON data_sources(commercial_use_allowed);

-- ============================================================================
-- SPECIES REGISTRY (taxonomic backbone)
-- ============================================================================

CREATE TABLE species (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scientific_name TEXT NOT NULL UNIQUE,
  common_names JSONB, -- {"en": "English Oak", "es": "Roble", "de": "Stieleiche"}
  kingdom TEXT NOT NULL CHECK (kingdom IN ('Animalia', 'Plantae', 'Fungi', 'Bacteria', 'Archaea')),
  phylum TEXT,
  class TEXT,
  "order" TEXT,
  family TEXT,
  genus TEXT,
  species_epithet TEXT,
  subspecies TEXT,
  taxon_rank TEXT NOT NULL, -- species, subspecies, variety, form
  
  -- External IDs
  gbif_key INTEGER UNIQUE,
  inaturalist_id INTEGER,
  wfo_id TEXT, -- World Flora Online
  mycobank_id INTEGER, -- for fungi
  bold_bin TEXT, -- DNA barcode
  
  -- Conservation Status
  iucn_status TEXT CHECK (iucn_status IN ('LC', 'NT', 'VU', 'EN', 'CR', 'EW', 'EX', NULL)), -- IUCN categories
  
  -- Biogeography
  native_ranges JSONB, -- array of ecoregion/country codes
  introduced_ranges JSONB,
  invasive_status TEXT, -- none, watch, invasive, highly_invasive
  
  -- Data Provenance
  source_id UUID REFERENCES data_sources(id),
  source_record_id TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_species_gbif ON species(gbif_key);
CREATE INDEX idx_species_scientific_name ON species USING GIN(to_tsvector('english', scientific_name));
CREATE INDEX idx_species_kingdom ON species(kingdom);

-- ============================================================================
-- SPECIES TRAITS (ecophysiological and functional)
-- ============================================================================

CREATE TABLE species_traits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id UUID NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  
  -- Ecophysiological Tolerances
  shade_tolerance TEXT CHECK (shade_tolerance IN ('very_low', 'low', 'moderate', 'high', 'very_high', NULL)),
  drought_tolerance TEXT CHECK (drought_tolerance IN ('very_low', 'low', 'moderate', 'high', 'very_high', NULL)),
  flood_tolerance TEXT CHECK (flood_tolerance IN ('very_low', 'low', 'moderate', 'high', 'very_high', NULL)),
  frost_tolerance TEXT CHECK (frost_tolerance IN ('very_low', 'low', 'moderate', 'high', 'very_high', NULL)),
  salt_tolerance TEXT CHECK (salt_tolerance IN ('very_low', 'low', 'moderate', 'high', 'very_high', NULL)),
  
  -- Temperature Range (Celsius)
  temp_min_c NUMERIC(5,1),
  temp_max_c NUMERIC(5,1),
  temp_optimal_c NUMERIC(5,1),
  
  -- Precipitation Range (mm/year)
  precip_min_mm NUMERIC(6,0),
  precip_max_mm NUMERIC(6,0),
  precip_optimal_mm NUMERIC(6,0),
  
  -- Soil Chemistry
  soil_ph_min NUMERIC(3,1),
  soil_ph_max NUMERIC(3,1),
  soil_ph_optimal NUMERIC(3,1),
  nitrogen_requirement TEXT CHECK (nitrogen_requirement IN ('very_low', 'low', 'moderate', 'high', 'very_high', NULL)),
  
  -- Soil Texture Preference
  soil_texture_preference TEXT[], -- [clay, loam, sand, silt, peat]
  
  -- Elevation
  elevation_min_m INTEGER,
  elevation_max_m INTEGER,
  
  -- Growth & Structure
  max_height_m NUMERIC(6,1),
  max_width_m NUMERIC(6,1),
  growth_rate_cm_per_year NUMERIC(5,1),
  lifespan_years INTEGER,
  crown_shape TEXT, -- columnar, spreading, pyramidal, round, weeping
  rooting_depth_m NUMERIC(4,1),
  
  -- Wood Properties (for timber species)
  wood_density_g_cm3 NUMERIC(4,2),
  wood_hardness_janka INTEGER,
  heartwood_color TEXT,
  
  -- Leaf Properties
  leaf_type TEXT CHECK (leaf_type IN ('broadleaf', 'needle', 'scale', 'grass', NULL)),
  leaf_size_mm NUMERIC(5,1),
  phenology TEXT CHECK (phenology IN ('evergreen', 'deciduous', 'semi_deciduous', 'drought_deciduous', NULL)),
  
  -- Functional Ecology
  nitrogen_fixing BOOLEAN DEFAULT false,
  mycorrhizal_type TEXT CHECK (mycorrhizal_type IN ('AM', 'ECM', 'ERM', 'ericoid', 'orchid', 'none', NULL)),
  pollinator_dependence TEXT CHECK (pollinator_dependence IN ('obligate', 'facultative', 'none', NULL)),
  pollinator_types TEXT[], -- [bee, butterfly, moth, bird, wind, water, self]
  seed_dispersal_mode TEXT[] CHECK (seed_dispersal_mode <@ ARRAY['wind', 'water', 'animal', 'gravity', 'explosive']),
  seed_mass_mg NUMERIC(6,2),
  
  -- Disturbance Response
  fire_response TEXT CHECK (fire_response IN ('resprouter', 'obligate_seeder', 'fire_sensitive', 'fire_adapted', NULL)),
  flood_response TEXT CHECK (flood_response IN ('tolerant', 'sensitive', 'avoider', NULL)),
  
  -- Carbon & Biomass
  carbon_sequestration_rate_kg_yr NUMERIC(7,2), -- per tree/individual
  above_ground_biomass_kg_m2 NUMERIC(6,2),
  
  -- Erosion & Soil
  erosion_control_potential TEXT CHECK (erosion_control_potential IN ('very_low', 'low', 'moderate', 'high', 'very_high', NULL)),
  soil_improvement_potential BOOLEAN,
  
  -- Data Quality
  source_id UUID REFERENCES data_sources(id),
  confidence_score NUMERIC(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
  data_completeness NUMERIC(3,2),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_species_traits_species ON species_traits(species_id);
CREATE INDEX idx_species_traits_tolerance ON species_traits(drought_tolerance, shade_tolerance, frost_tolerance);

-- ============================================================================
-- SPECIES USES (human applications)
-- ============================================================================

CREATE TABLE species_uses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id UUID NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  
  use_category TEXT NOT NULL, -- timber, food, medicine, ornamental, fiber, fuel, fodder, cultural, dye, tannin
  use_description TEXT,
  use_quality TEXT CHECK (use_quality IN ('excellent', 'good', 'moderate', 'poor', NULL)),
  
  sector TEXT, -- forestry, agriculture, agroforestry, restoration, urban, horticulture, nutraceutical
  maturity_years INTEGER, -- years until harvest/use
  yield_per_hectare NUMERIC(8,2), -- kg/ha or unit/ha
  market_value_usd_per_unit NUMERIC(10,2),
  
  commercial_availability TEXT CHECK (commercial_availability IN ('widely_available', 'limited', 'rare', 'extinct_in_wild', NULL)),
  trade_restrictions TEXT, -- CITES, endangered species act, etc.
  
  traditional_knowledge_culture TEXT,
  indigenous_use BOOLEAN DEFAULT false,
  
  notes TEXT,
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_species_uses_category ON species_uses(use_category);

-- ============================================================================
-- SPECIES OCCURRENCES (observation records)
-- ============================================================================

CREATE TABLE species_occurrences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id UUID NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  
  geom GEOMETRY(POINT, 4326) NOT NULL,
  
  -- Observation Details
  observation_date DATE,
  observation_type TEXT NOT NULL, -- specimen, human_observation, camera_trap, acoustic_detection, eDNA, machine_learning
  certainty TEXT CHECK (certainty IN ('certain', 'probable', 'uncertain', NULL)),
  
  -- Data Source
  source TEXT NOT NULL, -- GBIF, iNaturalist, eBird, OBIS, field_survey, herbarium
  source_record_id TEXT UNIQUE,
  source_dataset_id TEXT,
  
  -- Quality & Confidence
  coordinate_uncertainty_m INTEGER,
  confidence_score NUMERIC(3,2),
  
  -- Licensing & Attribution
  license TEXT NOT NULL, -- CC-BY, CC0, CC-BY-NC, etc.
  collector_name TEXT,
  attribution TEXT,
  occurrence_remarks TEXT,
  
  -- Provenance
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ingested_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_occurrences_geom ON species_occurrences USING GIST(geom);
CREATE INDEX idx_occurrences_species ON species_occurrences(species_id);
CREATE INDEX idx_occurrences_date ON species_occurrences(observation_date);
CREATE INDEX idx_occurrences_source ON species_occurrences(source);

-- ============================================================================
-- SPECIES INTERACTIONS (trophic & symbiotic relationships)
-- ============================================================================

CREATE TABLE species_interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id UUID NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  interacting_species_id UUID NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  
  interaction_type TEXT NOT NULL, -- symbiont, pollinator, seed_disperser, host, parasite, predator, prey, competitor
  interaction_strength TEXT CHECK (interaction_strength IN ('obligate', 'common', 'occasional', 'rare', NULL)),
  
  -- Ecological Context
  geographic_scope TEXT, -- global, tropical, temperate, etc.
  habitat_context TEXT,
  
  notes TEXT,
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_interactions_species ON species_interactions(species_id);
CREATE INDEX idx_interactions_type ON species_interactions(interaction_type);

-- ============================================================================
-- BIOMES & ECOREGIONS
-- ============================================================================

CREATE TABLE ecoregions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL, -- WWF ecoregion code
  name TEXT NOT NULL,
  biome TEXT NOT NULL, -- tropical_moist_forest, temperate_broadleaf, boreal_forest, grassland, desert, tundra, etc.
  realm TEXT NOT NULL, -- Palearctic, Nearctic, Afrotropic, Indomalayan, Australasian, Oceanian, Antarctic
  
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  area_km2 NUMERIC(12,2),
  
  -- Typical Climate Profile
  climate_profile JSONB, -- {temp_mean_c, temp_min_c, temp_max_c, precip_mm_yr, seasonality}
  
  -- Soil Profile
  soil_profile JSONB, -- {dominant_soil_types, ph_range, texture}
  
  -- Disturbance Regime
  typical_disturbance TEXT[],
  disturbance_frequency_years INTEGER,
  
  -- Biodiversity Metrics
  species_richness_rank TEXT, -- very_high, high, moderate, low
  endemism_level TEXT,
  
  -- Land Use
  primary_land_use TEXT[],
  protection_percentage NUMERIC(5,2),
  
  source_id UUID REFERENCES data_sources(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ecoregions_geom ON ecoregions USING GIST(geom);
CREATE INDEX idx_ecoregions_biome ON ecoregions(biome);
CREATE INDEX idx_ecoregions_realm ON ecoregions(realm);

-- ============================================================================
-- CLIMATE SIGNALS (time-series data per location)
-- ============================================================================

CREATE TABLE climate_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  geom GEOMETRY(POINT, 4326) NOT NULL,
  
  metric TEXT NOT NULL, -- temperature, precipitation, ndvi, fire_risk, drought_severity, wind_speed, humidity
  sub_metric TEXT, -- min, max, mean, std, percentile_90
  period TEXT NOT NULL, -- daily, dekadal, monthly, annual
  
  time_start DATE NOT NULL,
  time_end DATE,
  value NUMERIC(10,3) NOT NULL,
  unit TEXT NOT NULL, -- celsius, mm, unitless, days, index
  
  -- Data Quality
  data_quality_flag TEXT,
  confidence_score NUMERIC(3,2),
  
  source TEXT NOT NULL, -- ERA5, NASA_GPM, Sentinel-2, Open-Meteo, etc.
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_climate_geom ON climate_signals USING GIST(geom);
CREATE INDEX idx_climate_metric ON climate_signals(metric);
CREATE INDEX idx_climate_time ON climate_signals(time_start, time_end);

-- ============================================================================
-- DISTURBANCE EVENTS
-- ============================================================================

CREATE TABLE disturbance_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  geom GEOMETRY(GEOMETRY, 4326) NOT NULL, -- point or polygon
  
  event_type TEXT NOT NULL, -- fire, flood, drought, storm, pest_outbreak, disease, landslide, logging, mining
  event_subtype TEXT, -- e.g., wildfire, prescribed_fire, volcanic_fire
  
  start_date DATE NOT NULL,
  end_date DATE,
  duration_days INTEGER,
  
  severity TEXT CHECK (severity IN ('low', 'moderate', 'high', 'extreme', NULL)),
  severity_index NUMERIC(4,2), -- 0-1 or 0-100
  
  -- Spatial Impact
  affected_area_ha NUMERIC(12,2),
  affected_area_bounds GEOMETRY(POLYGON, 4326),
  
  -- Environmental Impact
  estimated_tree_loss_percent NUMERIC(5,2),
  estimated_biomass_loss_tons NUMERIC(12,2),
  carbon_released_tons NUMERIC(12,2),
  
  -- Data Source
  source TEXT NOT NULL, -- NASA_FIRMS, Sentinel-2, field_report, USGS
  source_id UUID REFERENCES data_sources(id),
  source_event_id TEXT UNIQUE,
  
  confidence_score NUMERIC(3,2),
  metadata JSONB,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  detected_at TIMESTAMPTZ
);

CREATE INDEX idx_disturbance_geom ON disturbance_events USING GIST(geom);
CREATE INDEX idx_disturbance_type ON disturbance_events(event_type);
CREATE INDEX idx_disturbance_date ON disturbance_events(start_date);

-- ============================================================================
-- SOIL PROFILES
-- ============================================================================

CREATE TABLE soil_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  geom GEOMETRY(POINT, 4326) NOT NULL,
  
  -- Depth Layer
  depth_cm_start INTEGER, -- 0, 5, 15, 30, 60, 100, 200
  depth_cm_end INTEGER,
  
  -- Chemical Properties
  ph_water NUMERIC(4,2),
  ph_kcl NUMERIC(4,2),
  soil_organic_carbon_g_kg NUMERIC(6,2),
  total_nitrogen_g_kg NUMERIC(6,2),
  phosphorus_mg_kg NUMERIC(7,1),
  potassium_mg_kg NUMERIC(7,1),
  cation_exchange_capacity_cmol_kg NUMERIC(6,2),
  
  -- Physical Properties
  clay_percent NUMERIC(5,2),
  silt_percent NUMERIC(5,2),
  sand_percent NUMERIC(5,2),
  bulk_density_kg_m3 NUMERIC(6,1),
  
  -- Hydrological Properties
  water_content_field_capacity_percent NUMERIC(5,2),
  water_content_wilting_point_percent NUMERIC(5,2),
  saturated_conductivity_mm_day NUMERIC(6,1),
  
  -- Biological Properties
  soil_microbial_biomass_mg_g NUMERIC(6,2),
  soil_respiration_co2_mg_kg_day NUMERIC(6,2),
  
  -- Data Source
  source_id UUID REFERENCES data_sources(id),
  source TEXT NOT NULL, -- SoilGrids, USDA_NRCS, field_survey, literature
  source_dataset_id TEXT,
  
  confidence_score NUMERIC(3,2),
  
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_soil_geom ON soil_profiles USING GIST(geom);
CREATE INDEX idx_soil_depth ON soil_profiles(depth_cm_start, depth_cm_end);

-- ============================================================================
-- PROTECTED AREAS & CONSERVATION ZONES
-- ============================================================================

CREATE TABLE protected_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wdpa_id INTEGER UNIQUE,
  
  name TEXT NOT NULL,
  country_iso3 TEXT,
  
  -- Designation
  designation TEXT,
  designation_type TEXT CHECK (designation_type IN ('national', 'international', 'regional', 'community', NULL)),
  iucn_category TEXT CHECK (iucn_category IN ('Ia', 'Ib', 'II', 'III', 'IV', 'V', 'VI', NULL)),
  
  geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
  
  -- Area & Status
  marine BOOLEAN DEFAULT false,
  terrestrial BOOLEAN DEFAULT true,
  area_km2 NUMERIC(12,2),
  
  status TEXT CHECK (status IN ('designated', 'proposed', 'inscribed', 'delisted', NULL)),
  status_year INTEGER,
  year_established INTEGER,
  
  -- Governance
  governance_type TEXT,
  management_authority TEXT,
  management_effectiveness TEXT,
  
  -- Legal Status
  legal_instrument TEXT,
  unesco_mab_biosphere BOOLEAN DEFAULT false,
  ramsar_wetland BOOLEAN DEFAULT false,
  
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_protected_geom ON protected_areas USING GIST(geom);
CREATE INDEX idx_protected_iucn ON protected_areas(iucn_category);

-- ============================================================================
-- REGULATIONS & COMPLIANCE RULES
-- ============================================================================

CREATE TABLE regulations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  name TEXT NOT NULL,
  regulation_type TEXT NOT NULL, -- environmental_law, forestry_code, water_law, protected_area_rule, ESG_standard
  
  jurisdiction TEXT NOT NULL, -- country ISO3, state code, region name
  jurisdictional_scope TEXT, -- national, regional, local, protected_area
  
  geom GEOMETRY(GEOMETRY, 4326), -- applicable geographic area (optional)
  
  -- Effective Dates
  effective_from DATE,
  effective_to DATE,
  
  -- Authority & References
  authority_agency TEXT,
  reference_url TEXT,
  official_text TEXT,
  
  summary TEXT NOT NULL,
  
  -- Sectors & Activities
  applicable_sectors TEXT[],
  
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_regulations_jurisdiction ON regulations(jurisdiction);
CREATE INDEX idx_regulations_geom ON regulations USING GIST(geom);

-- Structured Compliance Rules extracted from regulations
CREATE TABLE compliance_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  regulation_id UUID NOT NULL REFERENCES regulations(id) ON DELETE CASCADE,
  
  activity_type TEXT NOT NULL, -- logging, land_clearing, planting, discharge, construction, mining, dredging, water_extraction
  
  rule_type TEXT NOT NULL CHECK (rule_type IN ('prohibition', 'restriction', 'requirement', 'permit_required', 'best_practice')),
  rule_priority TEXT, -- critical, important, recommended
  
  -- Structured Conditions
  conditions JSONB NOT NULL, -- {buffer_m, season, habitat_type, species_protection, threshold, etc.}
  
  -- Plain Language
  description TEXT NOT NULL,
  penalty_description TEXT,
  
  permit_required BOOLEAN DEFAULT false,
  permit_authority TEXT,
  
  enforcement_likelihood TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_compliance_rules_regulation ON compliance_rules(regulation_id);
CREATE INDEX idx_compliance_rules_activity ON compliance_rules(activity_type);

-- ============================================================================
-- SPECIES CLIMATE SUITABILITY (projections)
-- ============================================================================

CREATE TABLE species_climate_suitability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  species_id UUID NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  ecoregion_id UUID NOT NULL REFERENCES ecoregions(id),
  
  -- Climate Scenario
  scenario TEXT NOT NULL CHECK (scenario IN ('current', 'SSP1-1.9', 'SSP1-2.6', 'SSP2-4.5', 'SSP3-7.0', 'SSP5-8.5')),
  time_horizon INTEGER, -- 2030, 2050, 2070, 2100
  
  -- Suitability Metrics
  suitability_score NUMERIC(3,2) CHECK (suitability_score >= 0 AND suitability_score <= 1),
  range_shift_km INTEGER,
  
  -- Risk Factors
  risk_factors JSONB, -- {heat_stress: 0.3, drought: 0.5, cold_stress: 0.1}
  
  -- Model Details
  model_type TEXT, -- maxent, random_forest, ensemble, sdm
  model_ensemble_members INTEGER,
  
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suitability_species ON species_climate_suitability(species_id);
CREATE INDEX idx_suitability_ecoregion ON species_climate_suitability(ecoregion_id);

-- ============================================================================
-- REFORESTATION RECIPES
-- ============================================================================

CREATE TABLE reforestation_recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  name TEXT NOT NULL,
  description TEXT,
  
  target_ecoregion_id UUID NOT NULL REFERENCES ecoregions(id),
  target_objective TEXT NOT NULL, -- biodiversity, carbon, water_protection, timber, agroforestry, food_production
  
  -- Climate Context
  current_climate BOOLEAN DEFAULT true,
  climate_scenario TEXT CHECK (climate_scenario IN ('SSP1-2.6', 'SSP2-4.5', 'SSP5-8.5', NULL)),
  time_horizon INTEGER,
  
  -- Species Composition
  species_mix JSONB NOT NULL, -- [{species_id: uuid, proportion: 0.3, density_per_ha: 400, spacing_m: 5}]
  total_density_per_ha INTEGER,
  planting_pattern TEXT, -- random, cluster, row, block
  
  -- Succession Planning
  succession_plan JSONB, -- [{phase: 1, year_range: "0-5", species_mix: [...], management: "..."}]
  
  -- Site Constraints
  constraints_addressed JSONB, -- {slope_max_percent: 30, water_table_min_m: 2, invasive_risk: true}
  soil_adaptation JSONB,
  
  -- Expected Outcomes
  establishment_years INTEGER,
  carbon_sequestration_20yr_tons_ha NUMERIC(7,2),
  biomass_20yr_tons_ha NUMERIC(7,2),
  
  biodiversity_metrics JSONB, -- {expected_species_richness: 45, native_species_percent: 0.85}
  
  -- Regulatory & Economic
  legal_requirements TEXT,
  estimated_cost_usd_per_ha NUMERIC(8,2),
  
  source_text TEXT, -- research_paper, ngo_manual, corporate_practice
  source_id UUID REFERENCES data_sources(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_recipes_ecoregion ON reforestation_recipes(target_ecoregion_id);
CREATE INDEX idx_recipes_objective ON reforestation_recipes(target_objective);

-- ============================================================================
-- MANUAL DATA ENTRIES (for user-contributed data)
-- ============================================================================

CREATE TABLE manual_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  entry_type TEXT NOT NULL CHECK (entry_type IN ('species_occurrence', 'species_trait', 'regulation', 'disturbance', 'soil_profile', 'observation')),
  target_table TEXT NOT NULL,
  
  data JSONB NOT NULL,
  geom GEOMETRY(POINT, 4326),
  
  -- Review Workflow
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'published')),
  submitted_by TEXT,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  
  reviewed_by TEXT,
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,
  
  published_record_id UUID REFERENCES species(id) ON DELETE SET NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_manual_entries_status ON manual_entries(status);
CREATE INDEX idx_manual_entries_geom ON manual_entries USING GIST(geom);

-- ============================================================================
-- ATTRIBUTION & LICENSING CHAIN
-- ============================================================================

CREATE TABLE query_attributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  query_id UUID UNIQUE NOT NULL,
  
  sources_used UUID[] NOT NULL, -- array of data_sources IDs
  attribution_chain JSONB NOT NULL, -- complete chain for citation
  
  query_timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDICES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_species_geom ON species_occurrences(geom);
CREATE INDEX idx_climate_signals_metric_time ON climate_signals(metric, time_start DESC);
CREATE INDEX idx_disturbance_date_type ON disturbance_events(start_date DESC, event_type);
