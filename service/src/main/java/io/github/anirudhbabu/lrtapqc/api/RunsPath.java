package io.github.anirudhbabu.lrtapqc.api;

/**
 * The part of a URL after /api/runs:
 *
 *   (nothing) or /         the list of runs
 *   /{run}/summary         finding counts by check and country
 *   /{run}/findings        findings, filtered and paged
 *
 * where {run} is a run id or "latest". run is null for the list.
 */
public record RunsPath(Kind kind, RunRef run) {

    public enum Kind { LIST, SUMMARY, FINDINGS }

    public static RunsPath parse(String pathInfo) {
        String path = pathInfo == null ? "" : pathInfo;
        path = path.replaceAll("^/+", "").replaceAll("/+$", "");
        if (path.isEmpty()) {
            return new RunsPath(Kind.LIST, null);
        }
        String[] parts = path.split("/");
        if (parts.length == 2) {
            Kind kind = switch (parts[1]) {
                case "summary" -> Kind.SUMMARY;
                case "findings" -> Kind.FINDINGS;
                default -> null;
            };
            if (kind != null) {
                return new RunsPath(kind, RunRef.parse(parts[0]));
            }
        }
        throw ApiException.notFound("no such resource: /api/runs/" + path);
    }
}
