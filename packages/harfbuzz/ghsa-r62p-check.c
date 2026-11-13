/* Regression check for GHSA-r62p-jr5f-3mjm (harfbuzz subsetter OOB read).
 *
 * FeatureTableSubstitutionRecord::sanitize() used to sanitize a substitute
 * Feature without the tag of the feature it replaces, so tag-specific
 * FeatureParams (here cv01's) were never bounds-checked. The subsetter then
 * read them using the original tag and could run past the table.
 *
 * The data below is upstream's own regression vector (src/test-serialize.cc,
 * test_feature_substitution_params_sanitize, harfbuzz commit 4a60bf8333): a
 * GSUB whose FeatureVariations substitutes feature 0 (cv01) with a Feature
 * carrying cvXX params. Complete, it is a valid table. Missing its final
 * byte, the cvXX params run past the end of the table.
 *
 * Observed through the public API: a fixed harfbuzz rejects the truncated
 * table at sanitize time, so the face reports no GSUB features; an affected
 * one (>= 5.3.0, <= 14.6.0) accepts it and reports cv01. Exits non-zero on
 * an affected build.
 */
#include <stdio.h>
#include <hb.h>
#include <hb-ot.h>

static const char data[] = {
  0, 1, 0, 1,                 /* GSUB 1.1 */
  0, 14, 0, 16, 0, 28,        /* ScriptList, FeatureList, LookupList */
  0, 0, 0, 30,                /* FeatureVariations */
  0, 0,                       /* ScriptList: no scripts */
  0, 1, 'c', 'v', '0', '1', 0, 8, /* FeatureList: cv01 */
  0, 0, 0, 0,                 /* cv01: no params, no lookups */
  0, 0,                       /* LookupList: no lookups */
  0, 1, 0, 0, 0, 0, 0, 1,     /* FeatureVariations 1.0, one record */
  0, 0, 0, 0, 0, 0, 0, 16,    /* Null ConditionSet, substitution */
  0, 1, 0, 0, 0, 1,           /* FeatureTableSubstitution 1.0, one record */
  0, 0, 0, 0, 0, 12,          /* Feature 0 */
  0, 4, 0, 0,                 /* Substitute: params, no lookups */
  0, 0, 0, 0, 0, 0, 0, 0,     /* cvXX: format, label, tooltip, sample */
  0, 0, 0, 0, 0, 1, 0, 0, 0x41, /* No named parameters, one character */
};

static hb_blob_t *
table_func (hb_face_t *face, hb_tag_t tag, void *user_data)
{
  (void) face;
  if (tag == HB_OT_TAG_GSUB)
    return hb_blob_reference ((hb_blob_t *) user_data);
  return hb_blob_get_empty ();
}

static unsigned
gsub_feature_count (unsigned length)
{
  hb_blob_t *blob = hb_blob_create (data, length, HB_MEMORY_MODE_READONLY, NULL, NULL);
  hb_face_t *face = hb_face_create_for_tables (table_func, blob,
                                               (hb_destroy_func_t) hb_blob_destroy);
  unsigned count = hb_ot_layout_table_get_feature_tags (face, HB_OT_TAG_GSUB, 0, NULL, NULL);
  hb_face_destroy (face);
  return count;
}

int
main (void)
{
  unsigned complete = gsub_feature_count (sizeof (data));
  unsigned truncated = gsub_feature_count (sizeof (data) - 1);
  printf ("GHSA-r62p check: complete GSUB features=%u, truncated GSUB features=%u\n",
          complete, truncated);
  if (complete != 1)
    {
      fprintf (stderr, "GHSA-r62p check: control failed, a valid GSUB was rejected\n");
      return 2;
    }
  if (truncated != 0)
    {
      fprintf (stderr, "GHSA-r62p check: AFFECTED, truncated cvXX substitute params were accepted\n");
      return 1;
    }
  return 0;
}
