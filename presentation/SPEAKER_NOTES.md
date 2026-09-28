# Speaker notes — CDC Streaming Pipeline

These notes are identical to the notes embedded in each slide of CDC_Project_Presentation.pptx.

## Slide 1 — CDC Streaming Pipeline

WHAT TO SAY
This is our proof of concept for streaming Oracle changes into a real-time SQL layer. In one sentence: a change committed in Oracle becomes queryable in RisingWave in about three seconds at the median, and we can show you where each of those seconds goes.

HOW TO EXPLAIN THE PICTURE
The strip at the bottom is the whole pipeline. Oracle is the source. LogMiner and Debezium capture changes from Oracle's redo log. Kafka transports them. RisingWave keeps query results current. Superset or any SQL client reads them.

FRAMING
This is not a technology tour. The squad gave us a question and constraints. We will walk through the decisions, what each one cost, what we measured, what we learned, and what we would do next.

QUESTION THIS SLIDE ANSWERS
What are we about to hear, and why should it matter?

TRANSITION
Let's start with why the question exists at all.

## Slide 2 — Business problem

QUESTION THIS SLIDE ANSWERS
Why do we need change data capture when we already have a lakehouse?

WHAT TO SAY
Today T24/Oracle data reaches the Bronze and Silver layers in scheduled batches. Anything that changes between two runs is invisible until the next run, and each run has to query the source to find what changed. Do not quote a batch frequency: the POC did not measure the current pipeline.

TERMS
CDC, change data capture: instead of asking the database "what changed?" on a schedule, we read the database's own transaction log as changes happen. Oracle already writes every committed change to its redo log for recovery; we reuse that stream.

WHY IT MATTERS
Fresher data for decisions, no heavy extract windows against the transactional database, and one change stream that many consumers can use.

THE POC QUESTION
It has two parts. Can a lighter, open-source stack deliver changes within a few seconds? And can it cope with XMLTYPE, CLOB and BLOB columns, which T24 relies on heavily? The brief calls the second part the make-or-break question.

SCOPE
Sandbox only, no production connection, and a complement to the lakehouse, not a replacement.

TRANSITION
Here is how the brief defined success, and where we landed.

## Slide 3 — Requirements scorecard

QUESTION THIS SLIDE ANSWERS
Did the POC do what it was asked to do?

WHAT TO SAY
The brief's end goal was that an insert, update or delete in Oracle shows up in RisingWave within a few seconds. Measured on 100,000 committed inserts, the median is 3.0 seconds and the 99th percentile 5.6 seconds, so the goal is met.

Walk the rows quickly:
- Capture of all three operation types: met. The connector runs, and inserts, updates and deletes all appear as events.
- Clear verdict on XMLTYPE, CLOB and BLOB: met, with caveats that get their own slide.
- Upserts with no duplicates: 100,000 source rows produced exactly 100,000 rows in RisingWave, and a spot check of XML, CLOB and BLOB values matched Oracle.
- Current-state query: the business view serves Superset.

BE HONEST ABOUT THE GAP
The brief asked us to extend the shared sandbox repository that already runs MinIO, Airflow, Lakekeeper and Trino. We built a standalone stack instead: it runs on Minikube in its own namespace, but not beside those components. The Kubernetes manifests are not yet committed, and the benchmark needed two table columns and the latency objects created by hand. That is fixable work, not a design problem.

TRANSITION
Now let's look at what we actually built.

## Slide 4 — What we built

QUESTION THIS SLIDE ANSWERS
What exactly is running?

WHAT TO SAY
Five components, left to right, each with one job:
1. Oracle 21c Express Edition is the source. The table APPUSER.STMT_ENTRY mimics a T24 statement entry: ten business columns including XMLTYPE, CLOB and BLOB, plus a measurement column. ARCHIVELOG mode and supplemental logging make every change readable from the redo log.
2. Debezium 3.6, running on Kafka Connect, is the capture layer. It reads the redo log through Oracle LogMiner and turns each change into an event with a before image, an after image and an operation code.
3. Kafka is the transport: one topic per table, T24.APPUSER.STMT_ENTRY, running in KRaft mode, which means Kafka manages its own metadata without ZooKeeper.
4. RisingWave 2.0 is the stream processor: it applies the events as upserts and keeps materialized views current.
5. Superset and any SQL client serve the results. Kafdrop is only an inspection UI.

DEPLOYMENT
Docker Compose was the reference build. The same stack is reproduced on Minikube in the namespace cdc-scb: StatefulSets for the stateful parts (Oracle, Kafka, RisingWave, Superset's metadata database), Deployments for the stateless ones, a Job that registers the connector, and a CronJob that heals it after restarts.

TRANSITION
Let's follow a single row through this picture.

## Slide 5 — How one change travels

QUESTION THIS SLIDE ANSWERS
What happens to one row, and how do we know how long each step takes?

WHAT TO SAY (step by step)
1. A session inserts a row and commits. For measurement, the row carries its own timestamp: Oracle's clock in microseconds, read just before the INSERT (column SRC_TS_US).
2. At commit, Oracle writes the change to its redo log.
3. Debezium runs LogMiner sessions that read the redo log. Changes come out in batches, about every 3.1 seconds. Debezium stamps each event with ts_ms, the time it processed it.
4. The event waits in the connector's queue, which is polled every half second, and is sent to Kafka. The producer stamps the Kafka message time.
5. RisingWave consumes it, upserts the table and advances its views at each one-second barrier. We echo every processed event back through Kafka so RisingWave's own producer stamps a real wall-clock time.
6. The current state is now queryable from Superset, DBeaver or psql.

WHY THIS MEASUREMENT DESIGN
Two traps we avoided. Oracle's commit time as reported by LogMiner has whole-second resolution, which overstates latency by about half a second on average; hence the microsecond source column. RisingWave's PROCTIME() is tied to its internal barrier clock and was measured half a second early to a second late; hence the echo. All containers run on one host, so there is a single clock and no skew.

The time labels are medians per hop. Medians do not add up exactly; the means do: 2.26 + 0.25 + 0.52 = 3.03 seconds.

TRANSITION
Why do we need each of these components at all?

## Slide 6 — Why each component exists

QUESTION THIS SLIDE ANSWERS
Could we drop a component? What does each one buy us, and what does it cost?

WHAT TO SAY
Read the table as "responsibility, reason, price".
- Oracle plus LogMiner: we read the log instead of re-querying tables, so there are no triggers and no application changes. The price is extra redo from ARCHIVELOG and supplemental logging.
- Debezium: it gives every change a standard envelope (before, after, operation, source position) and remembers its position, so it can restart where it stopped. The price is the capture stage, about 2.3 seconds, and no old LOB values.
- Kafka: capture never waits for consumers, and any consumer can replay history. The price is one more system to operate; in the POC it is one broker with no replication.
- RisingWave: SQL on streams, with results kept current, speaking the Postgres protocol, so standard tools connect. The price is about half a second of waiting for its one-second barrier, and it is a single node here.
- Superset is not part of CDC; it makes the result visible to non-engineers.

TERMS
Coupling: when one system has to wait for, or know about, another. Every box here exists to remove a coupling or a cost.

TRANSITION
The most consequential choice was how to read Oracle. Let's look at that decision.

## Slide 7 — Oracle CDC decision

QUESTION THIS SLIDE ANSWERS
Why LogMiner, and was it worth it?

TERMS
LogMiner is an Oracle utility that reads redo and archive logs and returns the changes as rows you can query. Debezium opens LogMiner sessions, reads those rows and converts them into events.

WHY WE CHOSE IT
It ships with Oracle Database, so there is no extra CDC licence. The alternative inside Debezium, XStream, requires a licence for Oracle GoldenGate, per Oracle's own XStream guide. LogMiner is Debezium's default adapter and is open source end to end. It reads logs, so there are no triggers and no application change. And the task brief prescribed LogMiner for this POC.

WHAT WE ACCEPTED
LogMiner is polled, not pushed: changes are released in batches. It cannot supply old LOB values. And mining sessions run inside Oracle, which costs CPU and memory on the source; the POC did not measure that cost, and it needs a DBA review before any production use.

WHAT IT COST, MEASURED
The capture stage, from the row's source timestamp to Debezium, has a median of 2.25 seconds. That is 74.6 percent of the mean end-to-end latency. Debezium released events in batches roughly every 3.1 seconds.

THE POINT
Architecture decisions are trade-offs. We bought licence-free CDC with about two seconds of latency, and the brief's "few seconds" goal still holds.

TRANSITION
What would the alternatives have given us?

## Slide 8 — Alternatives

QUESTION THIS SLIDE ANSWERS
Is there a faster way, and what would it cost?

HOW TO READ THE TABLE
Only the first row is measured. Every other latency cell is an expectation, not a result, and must be benchmarked on the target Oracle before anyone decides on it.

WHAT TO SAY
- The unbuffered LogMiner adapter is also listed in Debezium's documentation. It has the same licence position with a different buffering model. It is the cheapest next experiment.
- XStream via Debezium: Oracle pushes changes to a client. Expected lower latency, but using the XStream APIs requires an Oracle GoldenGate licence, and the connector needs Oracle client libraries.
- Oracle GoldenGate is Oracle's own replication product: expected low latency, but it is a separate commercial platform with its own skills and a vendor dependency.
- OpenLogReplicator, which Debezium supports with the olr adapter, parses redo files directly. It is open source, but Debezium introduced the adapter as experimental, and it needs direct read access to the redo and archive files.
- Query- or trigger-based extraction needs no licence, but it either re-reads tables or adds work to every T24 write, and query-based polling cannot easily see deletes.

THE POINT
Faster capture exists, but it is either licensed or less mature. LogMiner was the right POC choice; a production decision needs a benchmark of the top two alternatives.

TRANSITION
Once the change is captured, why put Kafka in the middle?

## Slide 9 — Kafka's role

QUESTION THIS SLIDE ANSWERS
Why not connect Debezium directly to RisingWave?

TERMS
- Topic: a named, append-only log of events.
- Partition: one ordered sequence within a topic. The POC uses one partition, so all changes to the table stay in commit order.
- Offset: an event's position in the partition. Each consumer remembers its own offset.

WHAT TO SAY
Kafka turns capture and consumption into two independent problems.
- Decoupling: Debezium keeps writing even if RisingWave is down or slow.
- Buffering: bursts queue in Kafka, not in Oracle or in the connector.
- Replay, which we actually observed: when we recreated the RisingWave table, it rebuilt all 100,000 current rows from the topic's history of about 400,000 events, without touching Oracle.
- Independence: the business table reads from the earliest offset, the raw-event audit table from the latest, and Kafdrop just watches. A future lakehouse sink could be added the same way.

POC VERSUS PRODUCTION
One broker, replication factor 1, one partition. That is fine for a sandbox but has no fault tolerance and no parallel consumption. Production needs at least three brokers, replication factor 3, and partitioning by key.

TRANSITION
Now the consumer that turns events into answers: RisingWave.

## Slide 10 — RisingWave's role

QUESTION THIS SLIDE ANSWERS
Why a streaming database, rather than transforming data later?

WHAT TO SAY
RisingWave understands Debezium's envelope natively. We declare the table with FORMAT DEBEZIUM and a primary key, ENTRY_ID. Inserts add rows, updates replace them, deletes remove them. That is upsert semantics, so there are no duplicates and no stale rows.

TERMS
A materialized view is a saved query whose result is stored and updated incrementally as each change arrives. Reading it costs the same as reading a table; nothing is recomputed from scratch. Our business view keeps the current row, extracts vendor, channel and terminal from the XML column, and attaches the measured latency.

A barrier is RisingWave's heartbeat: once a second (barrier_interval_ms = 1000) it commits a consistent snapshot, and results become visible at that point. That is where the processing stage's half-second average wait comes from.

EVIDENCE
100,000 source rows became exactly 100,000 rows in RisingWave. Spot checks of the XML text, the CLOB text and the BLOB bytes matched Oracle. Because RisingWave speaks the Postgres wire protocol, Superset, DBeaver and psql connect with no special driver.

TRANSITION
That brings us to the question the brief called make-or-break: T24's LOB and XML columns.

## Slide 11 — XMLTYPE, CLOB, BLOB

QUESTION THIS SLIDE ANSWERS
Can this stack carry T24's LOB and XML data? This is the brief's make-or-break question.

TERMS
- LOB, large object: CLOB for text, BLOB for binary; XMLTYPE is stored as a LOB too.
- Before image: the row as it was before an update or delete. Audit and "what changed" use cases need it.

THE VERDICT
Current values arrive intact: inserts carry XML as text, CLOB as text and BLOB as base64, which RisingWave decodes back to bytes. Old LOB values never arrive: LogMiner does not supply them, so Debezium sends the placeholder "__debezium_unavailable_value". For BLOB the placeholder itself arrives base64-encoded, so downstream code must recognise the encoded form. The binary workaround, a second BLOB column holding the XML, was tested and does not fix this.

WHAT IT COSTS
- On updates that do not touch a LOB, the new LOB value would also be missing. Debezium's reselect post-processor re-reads those columns from Oracle, which means an extra query per such event.
- LOB writes are expensive at the source: 1,000 updates took 0.078 seconds scalar versus 5.888 seconds with LOBs, about 75 times, and that is Oracle execution time, not pipeline latency.
- Large LOB transactions are slow end to end: 500,000 XML updates in one transaction delivered their first event after 34 minutes.
- Restart fragility: the XMLTYPE column breaks Debezium's schema-history record when the connector restarts. A CronJob resets the connector's offsets, which forces a fresh snapshot. Expected risk: a row deleted during the outage would not arrive as a delete event.

WHAT TO RECOMMEND
Test T24's real LOB sizes: Kafka's default message limit is about 1 MB. And decide per use case whether old LOB values are needed at all.

TRANSITION
Back to latency: where exactly do the three seconds go?

## Slide 12 — End-to-end latency

QUESTION THIS SLIDE ANSWERS
Where is the time spent?

HOW TO READ THE BAR
The bar is the mean latency of 3.03 seconds split into its three measured stages. Means add up exactly; medians do not, which is why the bar uses means and the cards show medians and P99.

WHAT TO SAY
- Capture, from the row's source timestamp to Debezium: 2.26 seconds on average, 74.6 percent of the total. Its mechanism is the LogMiner cycle: Debezium releases changes in batches, one about every 3.1 seconds, so each change waits for the next batch. It also includes the INSERT and COMMIT themselves, a few milliseconds.
- Hand-off, Debezium to Kafka: 0.25 seconds on average, never more than about half a second. That matches the connector queue's poll interval of 500 milliseconds, the documented default.
- Processing, Kafka to RisingWave: 0.52 seconds on average, P99 about one second. That matches RisingWave releasing results at one-second barriers.

THE IMPLICATION
Kafka and RisingWave together account for about 0.8 seconds on average. Even a perfect Kafka and RisingWave would leave more than two seconds. The capture stage is the lever.

TRANSITION
Now the full distribution, not just averages.

## Slide 13 — Benchmark results

QUESTION THIS SLIDE ANSWERS
What did we measure, and how good is it?

METHOD
Two runs of 50,000 inserts each on Minikube, on 27 September 2026. A PL/SQL loop inserted one row and committed it before the next: 184 and 173 commits per second. Every row carried an XMLTYPE, a CLOB and two BLOB values. Latency per event runs from the row's own Oracle timestamp to RisingWave's echo timestamp. We recomputed every statistic from the 100,000 raw per-event rows, not from a summary.

TERMS
- Median, P50: half the events were faster, half slower.
- P95 and P99: 95 and 99 percent of events were at or below this value.
- Maximum: the single slowest event.

WHAT TO SAY
Median 3.03 seconds, mean 3.03, P95 4.66, P99 5.59, maximum 12.60. 97.3 percent of events finished within 5 seconds. The histogram is one smooth hump between 1 and 6 seconds; the bars above 7 seconds are too small to see.

THROUGHPUT
About 180 commits per second, sustained with no backlog. That was the limit of one generator session, not of the pipeline; we never pushed the pipeline to its ceiling.

CONSISTENCY
An earlier Docker run reported in the README, 500,000 rows, had a median of 3.09 seconds and a maximum of 13.9 seconds: consistent, but reported, not re-verified from raw data. An older 500k screenshot shows a median of 4.8 seconds under conditions that were not recorded.

TRANSITION
The maximum of 12.6 seconds deserves its own slide.

## Slide 14 — P99 vs maximum

QUESTION THIS SLIDE ANSWERS
Is the pipeline's latency 12.6 seconds?

TERMS
- P99, the 99th percentile: 99 percent of observations are at or below this latency, and about 1 percent are above it. One odd event cannot move it much.
- MAX, the maximum: the single slowest event observed. It is one data point out of 100,000, so one stall can dominate it.

WHAT TO SAY
Our P99 is 5.59 seconds; our maximum is 12.60 seconds. The correct reading is not "the pipeline takes 12.6 seconds". It is: 99 percent of changes arrived within 5.6 seconds, and the 12.6 seconds is the worst tail.

We looked inside the tail. Every one of the 450 events above 7 seconds, 0.45 percent, falls into two short windows, at 16:37 and 16:39 UTC. In both, Oracle's own commits paused for two to five seconds, and capture and RisingWave slowed together. That points to an environment stall, not steady-state pipeline behaviour. Outside those two windows the maximum was 6.9 seconds.

WHAT WE CAN LEGITIMATELY CONCLUDE
Quote P99, and ideally P99.9, for service levels. Report the maximum as a flagged outlier with its cause, never as "the latency". The cause of the stalls is not yet established: candidates are the small redo logs switching every 12 to 16 seconds, and resource contention on a 4-CPU host with no pod limits.

NEXT STEP
Capture Oracle wait events and host metrics during the next run.

TRANSITION
If the tail is an environment problem, what sets the median?

## Slide 15 — What is actually the bottleneck

QUESTION THIS SLIDE ANSWERS
What would we optimise first, and why?

HOW TO READ THE CHART
Each dot is one change: when it was written, on the horizontal axis, and how long capture took, on the vertical axis. The saw-tooth is the signature of polling: right after Debezium releases a batch, new changes have the longest wait; just before the next release, the shortest.

WHAT TO SAY
- Observation: capture is 74.6 percent of mean latency.
- Evidence: the 100,000 events left Debezium in 185 batches, one every 3.16 seconds at the median. The saw-tooth shows each change waiting for the next batch.
- Interpretation: the median is set by three polling cycles (about 3.1 seconds in capture, 0.5 seconds in the connector queue, 1 second in RisingWave), not by data volume. What sets the 3.1-second cycle inside Debezium 3.6 is not yet established; Debezium 3.6 replaced the older sleep-and-batch tuning with a log-count based mining window. The connector's metrics would tell us.

POTENTIAL OPTIMISATIONS (expected, not measured)
- Larger redo logs: today two groups of 10 MB, switching every 12 to 16 seconds during the runs.
- Debezium 3.6 mining settings, and poll.interval.ms below 500 ms.
- RisingWave's barrier below one second.
Each costs CPU somewhere: in Oracle, Connect or RisingWave. Change one knob at a time and re-run the same measurement.

BACK OF THE ENVELOPE
If changes arrive evenly, each waits on average half a cycle. Halving a 3.1-second cycle would cut about 0.8 seconds from the median. That is an estimate to verify, not a result.

TRANSITION
A related misconception: if the pipeline is fast in volume, is it fast per event?

## Slide 16 — Throughput vs latency

QUESTION THIS SLIDE ANSWERS
Isn't a high-throughput pipeline automatically a low-latency one?

TERMS
- Throughput: how many changes per second the pipeline moves. It answers "does it keep up?"
- Latency: how long one change takes from commit to query. It answers "how fresh is each row?"

WHAT TO SAY (LEFT: continuous CDC)
One commit per row at about 180 per second. The median stayed flat between 2.9 and 3.2 seconds in every minute of both runs, so the pipeline kept up with no growing backlog. The two P99 spikes are the two stall episodes. The pipeline's maximum throughput was not reached; the single-session generator was the limit.

WHAT TO SAY (RIGHT: one large transaction)
In the team's sanity test, 500,000 scalar rows were updated in one transaction. Once they started flowing, they drained at roughly 1,300 rows per second, which is far higher throughput than the continuous run. Yet the first row arrived only after 3 minutes and the last after 9.4 minutes. The rate is derived as rows divided by the time from first to last event, and the test's start timestamp is only partly documented.

THE POINT
High throughput and low latency are different properties. Measure both, and say which one a requirement is about.

TRANSITION
What does that mean for scaling from 100,000 rows to millions?

## Slide 17 — Scalability

QUESTION THIS SLIDE ANSWERS
Will this scale from 100,000 rows to 1 or 5 million?

TWO DIFFERENT WORKLOADS
- Continuous CDC: many small transactions, like real banking activity. Tested: 100,000 rows on Minikube, median 3.03 seconds and flat; 500,000 rows on Docker as reported in the README, median 3.09 seconds, maximum 13.9 seconds. 1 million and 5 million continuous rows were not tested.
- Batch or backfill: one huge transaction. The team's sanity tests went from 50,000 to 500,000 rows.

WHAT TO SAY
With the buffered LogMiner adapter we used, Debezium emits a transaction only after its COMMIT, and holds it in the connector's memory until then. A 500,000-row transaction is therefore one unit: nothing arrives until Oracle has written all of it and Debezium has mined all of it. The chart shows the time to the first and the last event on a logarithmic scale. Scalar batches: seconds to minutes. LOB-heavy batches: the 500,000-row XML update delivered its first event after 34 minutes and its last after 59. A team note also records about 3 hours for 1 million rows, under conditions that were not written down.

THE POINT
Processing 5 million historical rows is not the same claim as handling 5 million real-time events. Transaction size, not row count, is the risk.

RECOMMENDATION (expected, to validate)
Load history through Debezium's snapshot or a bulk path, keep CDC transactions small, and run a continuous test at 1M and 5M rows before sizing anything.

TRANSITION
Let's put all the decisions and their prices on one page.

## Slide 18 — Key trade-offs

QUESTION THIS SLIDE ANSWERS
What did we consciously give up?

HOW TO READ IT
Each row is a decision, what it bought, what it cost, and how we know: measured in the runs, visible in configuration, or expected but not tested.

WHAT TO SAY (highlight three)
- LogMiner: licence-free, but about 2.3 seconds of capture and no old LOB values. This is the defining trade-off of the design.
- The connector-healer CronJob: it recovers automatically from the XMLTYPE restart bug, but it does so by resetting offsets, which forces a re-snapshot. A row deleted during an outage would not arrive as a delete. Acceptable in a sandbox, not in production.
- Database-wide ALL-column supplemental logging: complete row images for every table, but more redo for the whole database. In production, scope it to the captured tables and let a DBA size the redo impact.

The single broker with replication factor 1, and the single-node RisingWave, are simplicity choices for the POC. They are listed so nobody mistakes them for the production design.

TRANSITION
Enough slides. Let's watch one row travel live.

## Slide 19 — Live demo

QUESTION THIS SLIDE ANSWERS
Does it really work, end to end, right now?

FLOW (details and exact commands in DEMO_SCRIPT.md)
1. Insert the row DEMO-0001 in Oracle, with XML, CLOB and BLOB values, and commit.
2. LogMiner and Debezium pick it up within about 2 to 3 seconds.
3. Show the event in Kafdrop: operation "c", no before image, the full after image.
4. The row appears in RisingWave; the DBeaver result grid auto-refreshes every second.
5. Update only the amount. The new amount arrives, the CLOB is still intact in RisingWave, and the raw event's before image shows the placeholder instead of the old CLOB: the limitation from slide 11, live.
6. Delete the row. It disappears from RisingWave; Kafka carries a "d" event plus a tombstone.
7. Query the per-stage latency for this row: capture, hand-off and processing add up to the total.

WHAT TO TELL THE AUDIENCE TO WATCH
The row appearing within about 3 seconds, the before and after images, and stage times that add up.

IF IT FAILS
Say so plainly. Switch to the recorded runs of 27 September 2026 on slides 12 to 15 and say they are recorded, then check the connector status using the command in the demo script.

TRANSITION
So what would it take to go from this POC to production?

## Slide 20 — Production evolution

QUESTION THIS SLIDE ANSWERS
What stands between this POC and production?

WHAT TO SAY
Everything on the right-hand side is a future consideration; none of it exists in the POC today.

THE PATH, IN FOUR GATES
1. Stabilise: make the POC reproducible from git. Commit the manifests, put the benchmark columns and latency objects into the init scripts, and move the plaintext credentials out of the repository and into a secret store.
2. Tune and re-measure: capture cycle, redo log size, barrier interval, one change at a time with the same method.
3. Pilot on T24-like data: real LOB sizes, many concurrent sessions, and a DBA review of LogMiner's load and of supplemental logging scope.
4. Harden: high availability everywhere, security, monitoring with alerting, and disaster recovery.

THE TABLE, BRIEFLY
Kafka moves to three or more brokers with replication factor 3 and keyed partitions. RisingWave moves to a cluster with object storage. Schemas get a registry and evolution rules. Operations get lag and latency metrics, alerts, a dead-letter path and runbooks. Security gets a secret manager, TLS and access control. On the Oracle side, supplemental logging is scoped to captured tables, and archived logs get a retention policy; in the POC, 112 archived logs have accumulated and none has been deleted.

TRANSITION
Let me close with what we learned.

## Slide 21 — Final insights

WHAT TO SAY
Seven points, each with its "so what":
1. Licence-free CDC meets the goal: a median of 3.0 seconds and a P99 of 5.6 seconds from an Oracle commit to a RisingWave query.
2. The licence saving has a measured price: capture is 75 percent of latency, so optimising Kafka or RisingWave alone cannot move the median much.
3. Polling cycles, not hardware, set the median: tune them before buying capacity.
4. Report P99, not the maximum: 99 percent of changes finish in 5.6 seconds, and the 12.6-second maximum came from two Oracle stalls.
5. XMLTYPE, CLOB and BLOB values arrive intact, but old LOB values never do. Any T24 use case that needs them needs another design.
6. Transaction size, not row count, is the scaling risk: a 500,000-row XML transaction delayed its first event by 34 minutes.
7. Capture once, consume many times: Kafka lets new consumers, such as a future lakehouse sink, replay history without touching Oracle.

RECOMMENDATION
Proceed to a scoped pilot with T24-like LOB sizes and concurrency, capture tuning, and a DBA review of LogMiner's load. Keep the batch lakehouse, and add CDC where freshness matters.

CLOSE
Thank you. Happy to take questions. The backup evidence is in the QA notes and the demo script.
