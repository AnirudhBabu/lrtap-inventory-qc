package io.github.anirudhbabu.lrtapqc.api;

import io.github.anirudhbabu.lrtapqc.data.Series;
import io.github.anirudhbabu.lrtapqc.data.SeriesPoint;
import io.github.anirudhbabu.lrtapqc.data.Trend;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServletRequest;

/**
 * GET /api/series?country=DE&pollutant=SOX&sector=NATIONAL%20TOTAL[&run=latest]
 *
 * One country's values for a pollutant and sector, year by year, with the
 * QC07 trend line and the checks that reported a finding for each year in
 * the run. Everything needed to judge whether a flag is real.
 */
@WebServlet(urlPatterns = SeriesServlet.ROOT)
public class SeriesServlet extends JsonServlet {

    public static final String ROOT = "/api/series";

    @Override
    protected void get(HttpServletRequest request, JsonWriter out) {
        Params params = new Params(request.getParameterMap());
        String country = params.requiredText("country");
        String pollutant = params.requiredText("pollutant");
        String sector = params.requiredText("sector");
        String run = params.optionalText("run");
        long runId = resolve(RunRef.parse(run == null ? RunRef.LATEST : run));

        Series s = repository().series(runId, country, pollutant, sector).orElseThrow(
                () -> ApiException.notFound("no data for " + country + " / " + pollutant + " / " + sector));
        Trend trend = s.trend();

        out.beginObject()
                .name("runId").value(runId)
                .name("countryCode").value(s.countryCode())
                .name("pollutantCode").value(s.pollutantCode())
                .name("sectorCode").value(s.sectorCode())
                .name("unit").value(s.unit())
                .name("trend");
        if (trend == null) {
            out.nullValue();
        } else {
            out.beginObject()
                    .name("intercept").value(trend.intercept())
                    .name("slope").value(trend.slope())
                    .name("years").value(trend.years())
                    .endObject();
        }
        out.name("points").beginArray();
        for (SeriesPoint p : s.points()) {
            out.beginObject()
                    .name("year").value(p.year())
                    .name("value").value(p.value())
                    .name("notationKey").value(p.notationKey())
                    .name("trend");
            if (trend == null) {
                out.nullValue();
            } else {
                out.value(trend.valueAt(p.year()));
            }
            out.name("checks").stringArray(p.checks()).endObject();
        }
        out.endArray().endObject();
    }
}
