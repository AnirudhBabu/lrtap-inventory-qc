package io.github.anirudhbabu.lrtapqc.api;

import io.github.anirudhbabu.lrtapqc.data.Finding;
import io.github.anirudhbabu.lrtapqc.data.FindingFilter;
import io.github.anirudhbabu.lrtapqc.data.Page;
import io.github.anirudhbabu.lrtapqc.data.QcRepository;
import io.github.anirudhbabu.lrtapqc.data.Run;
import io.github.anirudhbabu.lrtapqc.data.Series;
import io.github.anirudhbabu.lrtapqc.data.SummaryRow;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** An in-memory repository for the HTTP tests. Records what it was asked. */
class FakeQcRepository implements QcRepository {

    final List<Run> runs = new ArrayList<>();
    final List<SummaryRow> summary = new ArrayList<>();
    final List<Finding> findings = new ArrayList<>();
    Series series;
    RuntimeException failWith;

    FindingFilter lastFilter;
    int lastLimit;
    int lastOffset;
    long lastSeriesRun;

    private void maybeFail() {
        if (failWith != null) {
            throw failWith;
        }
    }

    @Override
    public List<Run> runs() {
        maybeFail();
        return runs;
    }

    @Override
    public Optional<Long> latestRunId() {
        maybeFail();
        return runs.stream().map(Run::runId).max(Long::compare);
    }

    @Override
    public boolean runExists(long runId) {
        maybeFail();
        return runs.stream().anyMatch(r -> r.runId() == runId);
    }

    @Override
    public List<SummaryRow> summary(long runId) {
        maybeFail();
        return summary;
    }

    @Override
    public Page<Finding> findings(long runId, FindingFilter filter, int limit, int offset) {
        maybeFail();
        lastFilter = filter;
        lastLimit = limit;
        lastOffset = offset;
        return new Page<>(findings.size(), findings.stream().skip(offset).limit(limit).toList());
    }

    @Override
    public Optional<Series> series(long runId, String country, String pollutant, String sector) {
        maybeFail();
        lastSeriesRun = runId;
        if (series != null && series.countryCode().equals(country)
                && series.pollutantCode().equals(pollutant) && series.sectorCode().equals(sector)) {
            return Optional.of(series);
        }
        return Optional.empty();
    }
}
