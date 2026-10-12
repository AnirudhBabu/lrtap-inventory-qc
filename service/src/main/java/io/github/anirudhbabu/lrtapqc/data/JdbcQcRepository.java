package io.github.anirudhbabu.lrtapqc.data;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;
import javax.sql.DataSource;

/** QcRepository over the project's Oracle schema (db/). */
public final class JdbcQcRepository implements QcRepository {

    private final DataSource dataSource;

    public JdbcQcRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    /** Reads one row of a result set. */
    @FunctionalInterface
    private interface RowReader<T> {
        T read(ResultSet rs) throws SQLException;
    }

    private <T> List<T> query(String sql, List<?> binds, RowReader<T> reader) {
        try (Connection c = dataSource.getConnection();
             PreparedStatement ps = c.prepareStatement(sql)) {
            for (int i = 0; i < binds.size(); i++) {
                ps.setObject(i + 1, binds.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                List<T> rows = new ArrayList<>();
                while (rs.next()) {
                    rows.add(reader.read(rs));
                }
                return rows;
            }
        } catch (SQLException e) {
            throw new DataAccessException("query failed: " + sql, e);
        }
    }

    private static LocalDateTime toLocal(Timestamp t) {
        return t == null ? null : t.toLocalDateTime();
    }

    @Override
    public List<Run> runs() {
        return query("select r.run_id, r.started_at, r.finished_at,"
                        + " (select count(*) from qc_finding f where f.run_id = r.run_id) as findings"
                        + " from qc_run r order by r.run_id desc",
                List.of(),
                rs -> new Run(rs.getLong(1), toLocal(rs.getTimestamp(2)), toLocal(rs.getTimestamp(3)), rs.getLong(4)));
    }

    @Override
    public Optional<Long> latestRunId() {
        // max() returns one row, null when there are no runs.
        List<Long> ids = query("select max(run_id) from qc_run", List.of(),
                rs -> rs.getObject(1) == null ? null : rs.getLong(1));
        return Optional.ofNullable(ids.get(0));
    }

    @Override
    public boolean runExists(long runId) {
        return query("select count(*) from qc_run where run_id = ?", List.of(runId), rs -> rs.getLong(1)).get(0) > 0;
    }

    @Override
    public List<SummaryRow> summary(long runId) {
        return query("select f.check_id, c.title, c.severity, f.country_code, count(*)"
                        + " from qc_finding f join qc_check c on c.check_id = f.check_id"
                        + " where f.run_id = ?"
                        + " group by f.check_id, c.title, c.severity, f.country_code"
                        + " order by f.check_id, f.country_code",
                List.of(runId),
                rs -> new SummaryRow(rs.getString(1), rs.getString(2), rs.getString(3), rs.getString(4), rs.getLong(5)));
    }

    @Override
    public Page<Finding> findings(long runId, FindingFilter filter, int limit, int offset) {
        FindingQuery q = FindingQuery.of(runId, filter, limit, offset);
        long total = query(q.countSql(), q.countBinds(), rs -> rs.getLong(1)).get(0);
        List<Finding> items = query(q.pageSql(), q.pageBinds(), rs -> new Finding(
                rs.getString(1), rs.getString(2), rs.getString(3), rs.getString(4), rs.getInt(5),
                rs.getBigDecimal(6), rs.getBigDecimal(7), rs.getString(8)));
        return new Page<>(total, items);
    }

    /** A reported cell, before the run's findings are attached. */
    private record Reported(int year, BigDecimal value, String notationKey) {
    }

    @Override
    public Optional<Series> series(long runId, String country, String pollutant, String sector) {
        List<Object> cell = List.of(country, pollutant, sector);

        List<Reported> reported = query("select year, value, notation_key from emission"
                        + " where country_code = ? and pollutant_code = ? and sector_code = ? order by year",
                cell, rs -> new Reported(rs.getInt(1), rs.getBigDecimal(2), rs.getString(3)));

        // Which checks reported each year. A year can have a finding but no
        // reported value at all (QC01, a missing cell), so years come from both.
        Map<Integer, List<String>> checks = new TreeMap<>();
        List<Object> runAndCell = List.of(runId, country, pollutant, sector);
        query("select distinct year, check_id from qc_finding"
                        + " where run_id = ? and country_code = ? and pollutant_code = ? and sector_code = ?"
                        + " order by year, check_id",
                runAndCell, rs -> {
                    checks.computeIfAbsent(rs.getInt(1), y -> new ArrayList<>()).add(rs.getString(2));
                    return null;
                });

        if (reported.isEmpty() && checks.isEmpty()) {
            return Optional.empty();
        }

        Map<Integer, SeriesPoint> points = new TreeMap<>();
        for (Reported r : reported) {
            points.put(r.year(), new SeriesPoint(r.year(), r.value(), r.notationKey(),
                    List.copyOf(checks.getOrDefault(r.year(), List.of()))));
        }
        checks.forEach((year, ids) -> points.putIfAbsent(year, new SeriesPoint(year, null, null, List.copyOf(ids))));

        String unit = query("select unit from ref_pollutant where pollutant_code = ?", List.of(pollutant),
                rs -> rs.getString(1)).stream().findFirst().orElse(null);

        // qc07_trend has no row for a series without positive values, and a
        // null slope for a series with only one.
        Trend trend = query("select n_years, intercept, slope from qc07_trend"
                        + " where country_code = ? and pollutant_code = ? and sector_code = ?",
                cell, rs -> rs.getObject(3) == null ? null : new Trend(rs.getDouble(2), rs.getDouble(3), rs.getInt(1)))
                .stream().filter(t -> t != null).findFirst().orElse(null);

        return Optional.of(new Series(country, pollutant, sector, unit, trend, List.copyOf(points.values())));
    }
}
