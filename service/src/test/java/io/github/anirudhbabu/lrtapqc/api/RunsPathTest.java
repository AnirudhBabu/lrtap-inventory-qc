package io.github.anirudhbabu.lrtapqc.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

/** How the part of a URL after /api/runs is read. */
class RunsPathTest {

    @Test
    void noPathListsRuns() {
        assertEquals(RunsPath.Kind.LIST, RunsPath.parse(null).kind());
        assertEquals(RunsPath.Kind.LIST, RunsPath.parse("/").kind());
    }

    @Test
    void numberedRunSummary() {
        RunsPath p = RunsPath.parse("/12/summary");
        assertEquals(RunsPath.Kind.SUMMARY, p.kind());
        assertEquals(12L, p.run().id());
    }

    @Test
    void latestRunFindings() {
        RunsPath p = RunsPath.parse("/latest/findings");
        assertEquals(RunsPath.Kind.FINDINGS, p.kind());
        assertNull(p.run().id(), "latest is resolved later, against the database");
    }

    @Test
    void trailingSlashIsAccepted() {
        assertEquals(RunsPath.Kind.FINDINGS, RunsPath.parse("/3/findings/").kind());
    }

    @Test
    void runMustBeAPositiveNumberOrLatest() {
        for (String bad : new String[] {"/abc/summary", "/0/summary", "/-1/summary", "/99999999999999999999/summary"}) {
            ApiException e = assertThrows(ApiException.class, () -> RunsPath.parse(bad), bad);
            assertEquals(400, e.status());
            assertEquals("run must be a positive whole number or 'latest'", e.getMessage());
        }
    }

    @Test
    void unknownPathsAreNotFound() {
        for (String bad : new String[] {"/12", "/12/other", "/12/summary/extra"}) {
            ApiException e = assertThrows(ApiException.class, () -> RunsPath.parse(bad), bad);
            assertEquals(404, e.status());
        }
    }
}
