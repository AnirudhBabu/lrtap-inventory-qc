package io.github.anirudhbabu.lrtapqc.api;

import io.github.anirudhbabu.lrtapqc.data.QcRepository;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Base for the API's servlets: answers GET with JSON, and turns failures
 * into a JSON error with the right status. A request the API cannot answer
 * (ApiException) gets its own message; anything else is logged in full and
 * reported only as "internal error", so database details never reach the
 * caller.
 */
abstract class JsonServlet extends HttpServlet {

    /** Writes the response body for a GET; throws ApiException for a bad request. */
    protected abstract void get(HttpServletRequest request, JsonWriter out);

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
        try {
            JsonWriter out = new JsonWriter();
            get(request, out);
            send(response, 200, out.toString());
        } catch (ApiException e) {
            send(response, e.status(), error(e.getMessage()));
        } catch (RuntimeException e) {
            log("request failed: " + request.getRequestURI(), e);
            send(response, 500, error("internal error"));
        }
    }

    private static String error(String message) {
        return new JsonWriter().beginObject().name("error").value(message).endObject().toString();
    }

    private static void send(HttpServletResponse response, int status, String body) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(body);
    }

    protected QcRepository repository() {
        QcRepository repo = (QcRepository) getServletContext().getAttribute(AppListener.REPOSITORY);
        if (repo == null) {
            throw new IllegalStateException("no repository in the servlet context");
        }
        return repo;
    }

    /** The run id a reference stands for, or 404 if there is no such run. */
    protected long resolve(RunRef run) {
        QcRepository repo = repository();
        if (run.id() == null) {
            return repo.latestRunId().orElseThrow(() -> ApiException.notFound("no QC runs yet"));
        }
        if (!repo.runExists(run.id())) {
            throw ApiException.notFound("run " + run.id() + " not found");
        }
        return run.id();
    }
}
