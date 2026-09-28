# Presentation QA: CDC Streaming Pipeline

QA as of 27 Sep 2026. Deck: `CDC_Project_Presentation.pptx`, 21 slides, 16:9. Speaker notes are embedded on every slide and mirrored in `SPEAKER_NOTES.md`. The live demo is in `DEMO_SCRIPT.md`.

## 1. Main story

Problem → Requirements → Architecture → Decisions → Trade-offs → Measurements → Insights → Demo → Production evolution.

| # | Slide | Role in the story |
| --- | --- | --- |
| 1 | CDC Streaming Pipeline | Title; the headline result (3.0 s median) and the five-stage pipeline |
| 2 | Batch ingestion sees a change only on the next run | Business problem and the POC question |
| 3 | The brief's goal is met; sandbox integration is the gap | Requirements scorecard against the task brief |
| 4 | Five components, one responsibility each | Architecture as built, with both deployments |
| 5 | One committed row becomes queryable in about 3 seconds | One change's journey and its four timestamps |
| 6 | Each component removes one coupling or one cost | Why each component exists |
| 7 | LogMiner: no extra licence, at the price of capture latency | The Oracle CDC decision and its measured trade-off |
| 8 | Faster capture exists, but it is licensed or less mature | Alternatives, measured vs expected |
| 9 | Kafka decouples Oracle capture from every consumer | Kafka's role |
| 10 | RisingWave keeps results current instead of recomputing | RisingWave's role; materialized views |
| 11 | XML and LOB values arrive intact; old LOB values never do | The brief's make-or-break LOB/XML verdict |
| 12 | Three-quarters of the latency is spent capturing the change | Latency by stage |
| 13 | 100,000 committed inserts: median 3.0 s, P99 5.6 s | Benchmark results and distribution |
| 14 | The 12.6 s maximum is not what 99% of changes experience | P99 vs maximum |
| 15 | A ~3-second capture cycle sets the median | The bottleneck: observation → evidence → interpretation → optimisation |
| 16 | High throughput does not guarantee low latency | Throughput vs latency |
| 17 | Transaction size, not row count, is the scaling risk | Scalability: continuous vs batch/backfill |
| 18 | Every choice bought something and cost something | Trade-off matrix |
| 19 | Watch one row travel: insert, update, delete | Live demo flow |
| 20 | From POC to production: pilot first, then harden | Production evolution; future considerations only |
| 21 | What this POC taught us | Seven insights and the recommendation |

**Changes from the requested 20-slide outline.**
- The "Oracle CDC decision" and "LogMiner trade-off" slides are merged into slide 7, because they told the same story twice.
- Added slide 3, the requirements scorecard: the narrative asks for "Requirements", and the task brief defines success criteria.
- Added slide 11, the LOB/XML verdict: the task brief calls it the make-or-break section, and it was missing from the outline.
- The demo (19) comes before production evolution (20), following the requested narrative order.

The task brief itself asks for a 20–30 minute session. Budget about 21 minutes of talk plus the 7-minute demo. Slides 6, 9, 16 and 18 can be shortened if time runs out.

## 2. Source of truth

The request referred to an analysis document "to be provided", but no document was attached. The deck therefore uses the analysis produced and verified in the same working session, from these sources:

- **Task baseline:** `scb_ojt_cdc_project.pdf`, the OJT task brief.
- **Repository:** `README.md`, `docker/compose/docker-compose.yml`, `docker/connect/connectors/oracle-source.json`, `docker/oracle/initdb/*`, `docker/risingwave/sql/create-latency-pipeline.sql`, `scripts/sql/Risingwave_DBEAVER.sql`, `scripts/sql/oracle_DBEAVER.sql`, `k8s/*` manifests, `docs/*`, `dashboard_export_20260927T120914/`, and deleted files recovered from git history (LOB test scripts, `LOB-UNAVAILABLE-VALUE-FIX.md`).
- **Project notes outside the repository:** `NOTES/Task_Phases.txt`, `NOTES/TEST_Inserting_500k row.txt`, the `NOTES/OBSERVATION/*.png` screenshots, and the earlier deck `CDC_Streaming_POC.pptx`.
- **Live cluster, read-only, 27 Sep 2026:**
  - RisingWave `cdc_stmt_entry_latency_full`: 100,004 raw rows exported and recomputed.
  - RisingWave catalog and `SHOW PARAMETERS`.
  - Oracle `v$version`, `v$database`, `v$log`, `v$log_history`, `v$archived_log`, `dba_tab_columns` and `dba_lobs`.
  - Kafka topic describe and end offsets.
  - Kafka Connect status, config (keys only) and logs.
  - Pod status and restart reasons.
- **External references, opened and read:**
  - [Oracle 19c XStream Guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/introduction-to-xstream.html): "Using the XStream APIs requires purchasing a license for the Oracle GoldenGate product."
  - [Debezium Oracle connector docs](https://debezium.io/documentation/reference/stable/connectors/oracle.html): LogMiner is the default adapter; adapters listed: `logminer`, `logminer_unbuffered`, `xstream`, `olr`.
  - [Debezium 2.4.0.Beta2 release notes](https://debezium.io/blog/2023/09/13/debezium-2-4-beta2-released/): the OpenLogReplicator adapter was introduced as experimental and needs direct read access to redo and archive files.
  - [Debezium 3.6 LogMiner blog](https://debezium.io/blog/2026/07/06/oracle-logminer-no-more-tuning/): 3.6 replaced the `log.mining.sleep.time.*` and `batch.size.*` tuning with `log.mining.log.count.min`.
  - [Debezium CommonConnectorConfig.java (v3.0.0.Final)](https://raw.githubusercontent.com/debezium/debezium/v3.0.0.Final/debezium-core/src/main/java/io/debezium/config/CommonConnectorConfig.java): `poll.interval.ms` defaults to 500 ms.

## 3. Benchmark metrics used in the deck

| Metric | Value | Evidence type |
| --- | --- | --- |
| Events measured (Minikube) | 100,000 committed single-row inserts (2 runs × 50,000) | Measured, recomputed from raw rows |
| Median / mean end to end | 3.03 s / 3.03 s | Measured |
| P90 / P95 / P99 / P99.9 | 4.37 / 4.66 / 5.59 / 11.45 s | Measured |
| Minimum / maximum | 0.42 s / 12.60 s | Measured |
| Share within 5 s | 97.3% | Measured |
| Capture stage (source ts → Debezium) | median 2.25 s, P99 4.60 s, mean 2.26 s (74.6% of mean) | Measured |
| Hand-off (Debezium → Kafka CreateTime) | median 0.25 s, P99 0.50 s, mean 0.25 s (8.4%) | Measured |
| Processing (Kafka → RisingWave echo) | median 0.48 s, P99 1.03 s, mean 0.52 s (17.0%) | Measured |
| Debezium release cadence | 185 batches; median gap 3.16 s; ~560 events per batch | Measured, derived from per-event `ts_ms` |
| Tail above 7 s | 450 events (0.45%), all in two windows (16:37:04 and 16:39:54 UTC) with Oracle commit stalls of 2–5 s | Measured |
| Tail excluding those two windows | P99 5.35 s, max 6.91 s | Measured |
| Sustained source rate | 173–184 commits/s; flat per-minute median of 2.9–3.2 s | Measured; the generator was the limit |
| Redo logs | 2 groups × 10 MB; a log switch every ~12–16 s during the runs | Measured (Oracle views) |
| Docker 500k run | median 3.09 s, mean 3.11 s, max 13.9 s, min 0.22 s | Reported (README); not re-verified |
| Earlier 500k screenshot | median 4.82 s, mean 5.87 s, max 18.8 s | Reported (screenshot); run conditions not recorded |
| 1,000 updates, Oracle execution | 0.078 s scalar vs 5.888 s LOB (~75×) | Reported (team B8 note); Oracle time, not pipeline latency |
| Large-transaction sanity tests | e.g. 500k XML: first event 2,054 s (34 min), last 3,534 s | Reported (screenshots); start timestamp partly documented |
| Large-transaction drain rate | ~1,300 rows/s (500k scalar) | Derived: rows ÷ (last − first event) |

## 4. Assumptions

- The 27 Sep 2026 Minikube runs are the headline benchmark, because they are the only runs whose raw per-event data could be recomputed.
- Latency start = `SRC_TS_US`, the Oracle clock read just before the INSERT. It includes the INSERT and COMMIT, a few ms at ~180 commits/s. End = RisingWave's echo-sink Kafka timestamp. The team's own probe found that stamp about 50 ms earlier than query visibility.
- One host clock: all containers ran on one Minikube node, so no cross-host clock skew applies.
- The "~0.8 s" in "Kafka and RisingWave together" is the sum of the mean hand-off and processing stages.
- LOB/XML behaviour on UPDATE (before-image placeholder, reselected after-image) comes from the team's B4–B7 tests and the live connector config. It was not re-executed, because the brief was analysis-only and the benchmark data was left untouched.
- Batch-test durations come from DBeaver screenshots. The SQL that produced them is not in the repository.

## 5. Not established by the current project

- The pipeline's maximum sustainable throughput: the single-session generator, not the pipeline, was the limit.
- Behaviour with concurrent sessions, multiple tables, or T24-size LOBs; Kafka's default 1 MB message limit was not tested.
- LogMiner's CPU and memory load on the Oracle source.
- Latency of the alternatives (XStream, GoldenGate, OpenLogReplicator, unbuffered LogMiner): none was benchmarked.
- What sets Debezium 3.6's ~3.1 s mining cycle. The connector's metrics were not captured.
- The root cause of the two Oracle stall episodes.
- Update and delete latency at scale; deletes have only 1-second-resolution timing.
- HA, failover and recovery behaviour, and delivery guarantees under failure.
- Raw data behind the README's Docker 500k result, which is still in the stopped Docker volume. To verify, start that RisingWave and run the percentile query in `scripts/sql/Risingwave_DBEAVER.sql`.
- 1M and 5M continuous loads: not tested.

## 6. QA performed

| Check | Result |
| --- | --- |
| Package validation (pptx skill `validate.py`: schema, relationships, charts) | Passed |
| Visual render of all 21 slides in Microsoft PowerPoint 16 (PNG export), inspected slide by slide | First pass found 8 slides needing fixes: a marker crossing a label on slide 14, orphan words and awkward hyphen breaks, sparse boxes. All fixed, re-rendered and re-inspected |
| Text overflow, overlap, cut-off | None after fixes |
| Placeholder scan (`lorem`, `TODO`, `xxx`, `[insert`) | None |
| Credential scan of slide text and notes | None found |
| Key numbers present and consistent (3.03, 4.66, 5.59, 12.60 s, 74.6%, 2.25 s, 0.078 s / 5.888 s, 34 min, 185 batches, 97.3%) | Present; each traces to §3 |
| Speaker notes | Embedded on all 21 slides; identical copy in `SPEAKER_NOTES.md` |
| Charts | Native, editable PowerPoint charts: histogram, saw-tooth scatter, per-minute lines, log-scale batch bars |
| Fonts | Calibri only, so the deck renders the same on any Office install |

## 7. Fix before presenting

- **Superset latency chart:** its dataset includes two `TXN_2028` test inserts with a dummy `SRC_TS_US` (~56-year "latency"). Filter `src_ts_us > 1700000000000000`, or do not show that chart.
- **Credentials in git:** `.env`, `k8s/secrets/*.yaml`, `docker/connect/connectors/*.json` and `oracle-first-run.log` are committed with plaintext credentials, because the ignore file is named `.gitignore.txt` and git never reads it. Do not open these files on screen.
- **README contradictions,** in case someone opens the repository during Q&A:
  - It says Oracle 18c and ojdbc8; the build uses 21c XE and ojdbc11.
  - It calls the design "production-grade".
  - It describes the 75× figure as pipeline latency; it is Oracle execution time.
  - It references `quick-insert-test.ps1`, which has been deleted.
  - Some docs still name the topic `oracle21.APPUSER.STMT_ENTRY`; the real topic is `T24.APPUSER.STMT_ENTRY`.
- **Earlier deck (`CDC_Streaming_POC.pptx`):** it claims "near-zero lag" and "multi-table concurrent CDC", neither of which the evidence supports. Do not mix its slides into this deck.
