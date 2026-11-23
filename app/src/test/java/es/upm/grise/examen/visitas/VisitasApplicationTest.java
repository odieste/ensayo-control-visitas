package es.upm.grise.examen.visitas;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

/** Sin secreto ni base de datos, la aplicación arranca: /health responde y /registro explica qué falta. */
@SpringBootTest
@AutoConfigureMockMvc
class VisitasApplicationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void healthRespondeSinBaseDeDatos() throws Exception {
        mockMvc.perform(get("/health"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.exam_id").value("test-id"))
            .andExpect(jsonPath("$.commit").value("0123456789abcdef0123456789abcdef01234567"))
            .andExpect(jsonPath("$.credenciales").value(false));
    }

    @Test
    void registroSinSecretoExplicaElProblema() throws Exception {
        mockMvc.perform(post("/registro"))
            .andExpect(status().isInternalServerError())
            .andExpect(jsonPath("$.error").value(containsString("SECRET_NAME")));
    }
}
