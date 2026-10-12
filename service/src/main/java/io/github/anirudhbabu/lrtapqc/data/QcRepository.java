package io.github.anirudhbabu.lrtapqc.data;

import java.util.List;
import java.util.Optional;

/** Read access to QC runs, their findings, and the series behind them. */
public interface QcRepository {

    /** All runs, newest first. */
    List<Run> runs();

    Optional<Long> latestRunId();

    boolean runExists(long runId);

    /** Finding counts by check and country, ordered by check then country. */
    List<SummaryRow> summary(long runId);

    /** Findings matching the filter, ordered by check, country, pollutant, sector, year. */
    Page<Finding> findings(long runId, FindingFilter filter, int limit, int offset);

    /** Empty if the cell has neither reported values nor findings in the run. */
    Optional<Series> series(long runId, String countryCode, String pollutantCode, String sectorCode);
}
