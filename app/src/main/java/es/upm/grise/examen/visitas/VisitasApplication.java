package es.upm.grise.examen.visitas;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Aplicación del control: registra visitas en la base de datos Aurora del profesor. */
@SpringBootApplication
public class VisitasApplication {

    public static void main(String[] args) {
        SpringApplication.run(VisitasApplication.class, args);
    }
}
