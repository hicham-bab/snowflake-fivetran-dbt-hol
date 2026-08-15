# dbt Semantic Layer definitions

**Definitions do not live in this folder.** Under the latest spec, which the
Fusion engine requires, semantic annotations are embedded in the model they
describe, so they go in `../marts/_<track_key>__marts.yml` alongside the
contract.

See the worked examples in the cpg, energy and financial_services tracks, and
the stub in `../marts/_track__marts.yml`.

Top-level `metrics:` are still valid in a standalone file, and that is the
right home for a metric that spans more than one model. If your track has one,
add it here as `<track_key>.yml`:

```yaml
version: 2

metrics:
  - name: <cross_model_metric>
    label: <Label>
    description: FILL ME.
    type: ratio
    numerator: <metric_from_model_a>
    denominator: <metric_from_model_b>
```
