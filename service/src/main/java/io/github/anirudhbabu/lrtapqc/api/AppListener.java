package io.github.anirudhbabu.lrtapqc.api;

import io.github.anirudhbabu.lrtapqc.data.JdbcQcRepository;
import io.github.anirudhbabu.lrtapqc.data.SimpleDataSource;
import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;
import java.sql.Driver;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Collections;

/**
 * Connects the API to Oracle when Tomcat starts the application, using the
 * LRTAP_JDBC_* environment variables (see SimpleDataSource). If one is
 * missing the application fails to start, with the variable's name in
 * Tomcat's log, rather than failing later on the first request.
 */
@WebListener
public class AppListener implements ServletContextListener {

    /** The servlet-context attribute that holds the QcRepository. */
    public static final String REPOSITORY = "lrtapqc.repository";

    static final String ORACLE_DRIVER = "oracle.jdbc.OracleDriver";

    @Override
    public void contextInitialized(ServletContextEvent event) {
        ServletContext ctx = event.getServletContext();
        try {
            // Tomcat's DriverManager does not discover drivers inside a web
            // application on its own; loading the class registers it.
            Class.forName(ORACLE_DRIVER);
        } catch (ClassNotFoundException e) {
            throw new IllegalStateException("Oracle JDBC driver not found: " + ORACLE_DRIVER, e);
        }
        ctx.setAttribute(REPOSITORY, new JdbcQcRepository(SimpleDataSource.fromEnvironment(System.getenv())));
        ctx.log("lrtap-qc-api connected to " + System.getenv(SimpleDataSource.URL));
    }

    /** Unregisters the drivers this application loaded, so a redeploy does not leak them. */
    @Override
    public void contextDestroyed(ServletContextEvent event) {
        ClassLoader mine = getClass().getClassLoader();
        for (Driver driver : Collections.list(DriverManager.getDrivers())) {
            if (driver.getClass().getClassLoader() == mine) {
                try {
                    DriverManager.deregisterDriver(driver);
                } catch (SQLException e) {
                    event.getServletContext().log("could not unregister " + driver, e);
                }
            }
        }
    }
}
