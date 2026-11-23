package es.upm.grise.examen.visitas;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Rutas:
 * <ul>
 *   <li>GET  /health    estado de la aplicación (no toca la base de datos)</li>
 *   <li>GET  /registro  filas de la tabla registro con tu EXAM_ID</li>
 *   <li>POST /registro  inserta una fila y la devuelve</li>
 * </ul>
 * No se modifica durante el examen.
 */
@RestController
public class VisitasController {

    // cliente, instancia y ts los rellena un trigger de la base de datos, no la aplicación
    private static final String COLUMNAS = "id, exam_id, git_commit, host(cliente) AS cliente, instancia, ts::text AS ts";

    private final JdbcTemplate jdbc;
    private final String examId;
    private final String commit;
    private final String dbHost;
    private final String secretName;
    private final String usuario;

    public VisitasController(JdbcTemplate jdbc,
                             @Value("${control-visitas.exam-id}") String examId,
                             @Value("${control-visitas.commit}") String commit,
                             @Value("${control-visitas.db-host}") String dbHost,
                             @Value("${control-visitas.secret-name}") String secretName,
                             @Value("${spring.datasource.username}") String usuario) {
        this.jdbc = jdbc;
        this.examId = examId;
        this.commit = commit;
        this.dbHost = dbHost;
        this.secretName = secretName;
        this.usuario = usuario;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> estado = new LinkedHashMap<>();
        estado.put("exam_id", examId);
        estado.put("commit", commit);
        estado.put("db_host", dbHost);
        estado.put("credenciales", !usuario.isBlank());
        return estado;
    }

    @GetMapping("/registro")
    public List<Map<String, Object>> listar() {
        comprobarCredenciales();
        return jdbc.queryForList("SELECT " + COLUMNAS + " FROM registro WHERE exam_id = ? ORDER BY id", examId);
    }

    @PostMapping("/registro")
    public ResponseEntity<Map<String, Object>> registrar() {
        comprobarCredenciales();
        Map<String, Object> fila = jdbc.queryForMap(
            "INSERT INTO registro (exam_id, git_commit) VALUES (?, ?) RETURNING " + COLUMNAS, examId, commit);
        return ResponseEntity.status(HttpStatus.CREATED).body(fila);
    }

    private void comprobarCredenciales() {
        if (secretName.isBlank()) {
            throw new IllegalStateException("Falta la variable de entorno SECRET_NAME: el contenedor no sabe qué secreto leer");
        }
        if (usuario.isBlank()) {
            throw new IllegalStateException("No se ha podido leer el secreto '" + secretName
                + "' al arrancar (¿existe en tu cuenta? ¿tiene la aplicación credenciales de AWS?). Mira: docker logs contenedor-control-visitas");
        }
    }

    /** Cualquier error se devuelve como JSON con la causa raíz: el mensaje de PostgreSQL ayuda a diagnosticar. */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> error(Exception e) {
        Throwable causa = e;
        while (causa.getCause() != null && causa.getCause() != causa) {
            causa = causa.getCause();
        }
        String mensaje = causa.getClass().getSimpleName() + ": " + causa.getMessage();
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of("error", mensaje));
    }
}
