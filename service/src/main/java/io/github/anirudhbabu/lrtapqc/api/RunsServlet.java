package io.github.anirudhbabu.lrtapqc.api;

import io.github.anirudhbabu.lrtapqc.data.Finding;
import io.github.anirudhbabu.lrtapqc.data.FindingFilter;
import io.github.anirudhbabu.lrtapqc.data.Page;
import io.github.anirudhbabu.lrtapqc.data.Run;
import io.github.anirudhbabu.lrtapqc.data.SummaryRow;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;

/**
 * GET /api/runs                    runs, newest first
 * GET /api/runs/{run}/summary      finding counts by check and country
 * GET /api/runs/{run}/findings     findings; optional filters check, country,
 *                                  pollutant, sector, year; paged by limit
 *                                  (1-1000, default 100) and offset
 *
 * {run} is a run id or "latest".
 */
@WebServlet(urlPatterns = {RunsServlet.ROOT, RunsServlet.ROOT + "/*"})
public class RunsServlet extends JsonServlet {

    public static final String ROOT = "/api/runs";

    static final int DEFAULT_LIMIT = 100;
    static final int MAX_LIMIT = 1000;
    static final int MAX_OFFSET = 1_000_000_000;

    @Override
    protected void get(HttpServletRequest request, JsonWriter out) {
        RunsPath path = RunsPath.parse(request.getPathInfo());
        switch (path.kind()) {
            case LIST -> writeRuns(out);
            case SUMMARY -> writeSummary(resolve(path.run()), out);
            case FINDINGS -> writeFindings(resolve(path.run()), new Params(request.getParameterMap()), out);
        }
    }

    private void writeRuns(JsonWriter out) {
        out.beginObject().name("runs").beginArray();
        for (Run r : repository().runs()) {
            out.beginObject()
                    .name("runId").value(r.runId())
                    .name("startedAt").value(r.startedAt() == null ? null : r.startedAt().toString())
                    .name("finishedAt").value(r.finishedAt() == null ? null : r.finishedAt().toString())
                    .name("findings").value(r.findings())
                    .endObject();
        }
        out.endArray().endObject();
    }

    private void writeSummary(long runId, JsonWriter out) {
        out.beginObject().name("runId").value(runId).name("rows").beginArray();
        for (SummaryRow row : repository().summary(runId)) {
            out.beginObject()
                    .name("checkId").value(row.checkId())
                    .name("title").value(row.title())
                    .name("severity").value(row.severity())
                    .name("countryCode").value(row.countryCode())
                    .name("findings").value(row.findings())
                    .endObject();
        }
        out.endArray().endObject();
    }

    private void writeFindings(long runId, Params params, JsonWriter out) {
        FindingFilter filter = new FindingFilter(
                params.optionalText("check"),
                params.optionalText("country"),
                params.optionalText("pollutant"),
                params.optionalText("sector"),
                params.optionalInteger("year", 1900, 2100));
        int limit = params.optionalInt("limit", 1, MAX_LIMIT, DEFAULT_LIMIT);
        int offset = params.optionalInt("offset", 0, MAX_OFFSET, 0);

        Page<Finding> page = repository().findings(runId, filter, limit, offset);
        out.beginObject()
                .name("runId").value(runId)
                .name("total").value(page.total())
                .name("limit").value(limit)
                .name("offset").value(offset)
                .name("findings").beginArray();
        for (Finding f : page.items()) {
            out.beginObject()
                    .name("checkId").value(f.checkId())
                    .name("countryCode").value(f.countryCode())
                    .name("pollutantCode").value(f.pollutantCode())
                    .name("sectorCode").value(f.sectorCode())
                    .name("year").value(f.year())
                    .name("observed").value(f.observed())
                    .name("expected").value(f.expected())
                    .name("detail").value(f.detail())
                    .endObject();
        }
        out.endArray().endObject();
    }
}
