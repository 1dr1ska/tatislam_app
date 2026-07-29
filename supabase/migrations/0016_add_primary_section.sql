-- Add primary_section_id to publications table
ALTER TABLE publications ADD COLUMN primary_section_id UUID REFERENCES sections(id);

-- For existing publications, set primary_section_id to the first section they belong to
UPDATE publications p SET primary_section_id = (
  SELECT ps.section_id FROM publication_sections ps 
  WHERE ps.publication_id = p.id 
  ORDER BY ps.section_id 
  LIMIT 1
);

-- Make primary_section_id NOT NULL after backfill
ALTER TABLE publications ALTER COLUMN primary_section_id SET NOT NULL;