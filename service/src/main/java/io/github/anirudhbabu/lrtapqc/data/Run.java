package io.github.anirudhbabu.lrtapqc.data;

import java.time.LocalDateTime;

/** One execution of qc_runner.run_all. finishedAt is null if it never finished. */
public record Run(long runId, LocalDateTime startedAt, LocalDateTime finishedAt, long findings) {
}
