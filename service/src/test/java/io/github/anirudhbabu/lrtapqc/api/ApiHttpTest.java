package io.github.anirudhbabu.lrtapqc.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.github.anirudhbabu.lrtapqc.data.Finding;
import io.github.anirudhbabu.lrtapqc.data.FindingFilter;
import io.github.anirudhbabu.lrtapqc.data.Run;
import io.github.anirudhbabu.lrtapqc.data.Series;
import io.github.anirudhbabu.lrtapqc.data.SeriesPoint;
import io.github.anirudhbabu.lrtapqc.data.SummaryRow;
import io.github.anirudhbabu.lrtapqc.data.Trend;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.List;
import org.apache.catalina.Context;
import org.apache.catalina.LifecycleException;
import org.apache.catalina.startup.Tomcat;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The servlets over real HTTP, in an embedded Tomcat, with an in-memory
 * repository in place of Oracle. Checks status codes and the exact JSON.
 */
class ApiHttpTest {

    private Tomcat tomcat;
    private FakeQcRepository repo;
    private final HttpClient http = HttpClient.newHttpClient();
    private int port;

    @BeforeEach
    void startTomcat() throws LifecycleException, IOException {
        repo = new FakeQcRepository();
        Path base = Files.createTempDirectory("lrtap-qc-api-test");
        tomcat = new Tomcat();
        tomcat.setBaseDir(base.toString());
        tomcat.setPort(0);
        Context ctx = tomcat.addContext("", base.toString());
        ctx.getServletContext().setAttribute(AppListener.REPOSITORY, repo);
        // The same URL patterns the @WebServlet annotations declare.
        Tomcat.addServlet(ctx, "runs", new RunsServlet());
        ctx.addServletMappingDecoded(RunsServlet.ROOT, "runs");
        ctx.addServletMappingDecoded(RunsServlet.ROOT + "/*", "runs");
        Tomcat.addServlet(ctx, "series", new SeriesServlet());
        ctx.addServletMappingDecoded(SeriesServlet.ROOT, "series");
        tomcat.getConnector();
        tomcat.start();
        port = tomcat.getConnector().getLocalPort();
    }

    @AfterEach
    void stopTomcat() throws LifecycleException {
        tomcat.stop();
        tomcat.destroy();
    }

    private HttpResponse<String> get(String pathAndQuery) throws Exception {
        HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + pathAndQuery)).build();
        return http.send(request, HttpResponse.BodyHandlers.ofString());
    }

    private void addRuns() {
        repo.runs.add(new Run(2, LocalDateTime.parse("2026-10-12T09:40:00"), LocalDateTime.parse("2026-10-12T09:41:05"), 459177));
        repo.runs.add(new Run(1, LocalDateTime.parse("2026-10-11T08:00:00"), null, 0));
    }

    @Test
    void listsRuns() throws Exception {
        addRuns();
        HttpResponse<String> r = get("/api/runs");
        assertEquals(200, r.statusCode());
        assertTrue(r.headers().firstValue("Content-Type").orElse("").startsWith("application/json"));
        assertEquals("{\"runs\":["
                + "{\"runId\":2,\"startedAt\":\"2026-10-12T09:40\",\"finishedAt\":\"2026-10-12T09:41:05\",\"findings\":459177},"
                + "{\"runId\":1,\"startedAt\":\"2026-10-11T08:00\",\"finishedAt\":null,\"findings\":0}]}", r.body());
    }

    @Test
    void summarisesTheLatestRun() throws Exception {
        addRuns();
        repo.summary.add(new SummaryRow("QC05", "Sectors do not sum to the national total", "ERROR", "LV", 35));
        HttpResponse<String> r = get("/api/runs/latest/summary");
        assertEquals(200, r.statusCode());
        assertEquals("{\"runId\":2,\"rows\":[{\"checkId\":\"QC05\",\"title\":\"Sectors do not sum to the national total\","
                + "\"severity\":\"ERROR\",\"countryCode\":\"LV\",\"findings\":35}]}", r.body());
    }

    @Test
    void unknownRunIsNotFound() throws Exception {
        addRuns();
        HttpResponse<String> r = get("/api/runs/7/summary");
        assertEquals(404, r.statusCode());
        assertEquals("{\"error\":\"run 7 not found\"}", r.body());
    }

    @Test
    void latestWithNoRunsIsNotFound() throws Exception {
        HttpResponse<String> r = get("/api/runs/latest/findings");
        assertEquals(404, r.statusCode());
        assertEquals("{\"error\":\"no QC runs yet\"}", r.body());
    }

    @Test
    void findingsArePagedAndFiltered() throws Exception {
        addRuns();
        for (int year = 2020; year <= 2024; year++) {
            repo.findings.add(new Finding("QC05", "LV", "PM10", "NATIONAL TOTAL", year,
                    new BigDecimal("20.4106"), new BigDecimal("21.5548"),
                    "Sum of NFR sectors differs from the reported national total"));
        }
        HttpResponse<String> r = get("/api/runs/2/findings?check=QC05&country=LV&limit=2&offset=1");
        assertEquals(200, r.statusCode());
        assertEquals(new FindingFilter("QC05", "LV", null, null, null), repo.lastFilter);
        assertEquals(2, repo.lastLimit);
        assertEquals(1, repo.lastOffset);
        assertEquals("{\"runId\":2,\"total\":5,\"limit\":2,\"offset\":1,\"findings\":["
                + "{\"checkId\":\"QC05\",\"countryCode\":\"LV\",\"pollutantCode\":\"PM10\",\"sectorCode\":\"NATIONAL TOTAL\","
                + "\"year\":2021,\"observed\":20.4106,\"expected\":21.5548,"
                + "\"detail\":\"Sum of NFR sectors differs from the reported national total\"},"
                + "{\"checkId\":\"QC05\",\"countryCode\":\"LV\",\"pollutantCode\":\"PM10\",\"sectorCode\":\"NATIONAL TOTAL\","
                + "\"year\":2022,\"observed\":20.4106,\"expected\":21.5548,"
                + "\"detail\":\"Sum of NFR sectors differs from the reported national total\"}]}", r.body());
    }

    @Test
    void findingsUseDefaultPaging() throws Exception {
        addRuns();
        assertEquals(200, get("/api/runs/2/findings").statusCode());
        assertEquals(100, repo.lastLimit);
        assertEquals(0, repo.lastOffset);
        assertEquals(new FindingFilter(null, null, null, null, null), repo.lastFilter);
    }

    @Test
    void badParametersAreRejected() throws Exception {
        addRuns();
        HttpResponse<String> r = get("/api/runs/2/findings?limit=0");
        assertEquals(400, r.statusCode());
        assertEquals("{\"error\":\"parameter limit must be a whole number from 1 to 1000\"}", r.body());
        assertEquals(400, get("/api/runs/2/findings?year=nineteen").statusCode());
        assertEquals(400, get("/api/runs/abc/findings").statusCode());
    }

    @Test
    void unknownPathsAreNotFound() throws Exception {
        addRuns();
        assertEquals(404, get("/api/runs/2/other").statusCode());
    }

    @Test
    void seriesHasPointsTrendAndChecks() throws Exception {
        addRuns();
        double slope = Math.log10(0.9);
        repo.series = new Series("XA", "NOX", "S1", "kt", new Trend(2 - 2010 * slope, slope, 3), List.of(
                new SeriesPoint(2010, new BigDecimal("100"), null, List.of()),
                new SeriesPoint(2011, null, "NE", List.of("QC03")),
                new SeriesPoint(2012, new BigDecimal("81"), null, List.of("QC06", "QC07"))));
        HttpResponse<String> r = get("/api/series?country=XA&pollutant=NOX&sector=S1");
        assertEquals(200, r.statusCode());
        assertEquals(2L, repo.lastSeriesRun);
        String body = r.body();
        assertTrue(body.startsWith("{\"runId\":2,\"countryCode\":\"XA\",\"pollutantCode\":\"NOX\",\"sectorCode\":\"S1\","
                + "\"unit\":\"kt\",\"trend\":{\"intercept\":"), body);
        assertTrue(body.contains("\"years\":3},\"points\":[{\"year\":2010,\"value\":100,\"notationKey\":null,\"trend\":"), body);
        assertTrue(body.contains("{\"year\":2011,\"value\":null,\"notationKey\":\"NE\",\"trend\":"), body);
        assertTrue(body.endsWith(",\"checks\":[\"QC06\",\"QC07\"]}]}"), body);
    }

    @Test
    void seriesWithoutTrendHasNullTrend() throws Exception {
        addRuns();
        repo.series = new Series("XA", "NOX", "S1", "kt", null, List.of(
                new SeriesPoint(2010, null, "NO", List.of())));
        assertEquals("{\"runId\":2,\"countryCode\":\"XA\",\"pollutantCode\":\"NOX\",\"sectorCode\":\"S1\","
                + "\"unit\":\"kt\",\"trend\":null,\"points\":[{\"year\":2010,\"value\":null,\"notationKey\":\"NO\","
                + "\"trend\":null,\"checks\":[]}]}", get("/api/series?country=XA&pollutant=NOX&sector=S1").body());
    }

    @Test
    void seriesCanUseAnEarlierRun() throws Exception {
        addRuns();
        repo.series = new Series("XA", "NOX", "S1", "kt", null, List.of());
        assertEquals(200, get("/api/series?country=XA&pollutant=NOX&sector=S1&run=1").statusCode());
        assertEquals(1L, repo.lastSeriesRun);
    }

    @Test
    void seriesNeedsAllThreeParameters() throws Exception {
        addRuns();
        HttpResponse<String> r = get("/api/series?country=DE&pollutant=SOX");
        assertEquals(400, r.statusCode());
        assertEquals("{\"error\":\"missing parameter: sector\"}", r.body());
    }

    @Test
    void sectorWithSpacesWorksWhenEncoded() throws Exception {
        addRuns();
        repo.series = new Series("DE", "SOX", "NATIONAL TOTAL", "kt", null, List.of());
        assertEquals(200, get("/api/series?country=DE&pollutant=SOX&sector=NATIONAL%20TOTAL").statusCode());
    }

    @Test
    void unknownSeriesIsNotFound() throws Exception {
        addRuns();
        HttpResponse<String> r = get("/api/series?country=XA&pollutant=NOX&sector=ZZ");
        assertEquals(404, r.statusCode());
        assertEquals("{\"error\":\"no data for XA / NOX / ZZ\"}", r.body());
    }

    @Test
    void failuresDoNotLeakInternals() throws Exception {
        repo.failWith = new IllegalStateException("ORA-00942: table or view does not exist");
        HttpResponse<String> r = get("/api/runs");
        assertEquals(500, r.statusCode());
        assertEquals("{\"error\":\"internal error\"}", r.body());
        assertFalse(r.body().contains("ORA-"));
    }
}
