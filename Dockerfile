# Imagen base: solo el JRE 17 de Eclipse Temurin sobre Alpine (ligera)
FROM eclipse-temurin:17-jre-alpine

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiamos el JAR generado por Maven y lo renombramos a app.jar
COPY target/*.jar app.jar

# Puerto donde escucha Spring Boot
EXPOSE 8080

# Comando que se ejecuta al arrancar el contenedor
ENTRYPOINT ["java", "-jar", "app.jar"]
