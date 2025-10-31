# 1. Base Image:
# - Usamos Python 3.11 (para que coincida con tu CI y tu README)
# - Usamos "slim-bullseye" (Debian) en lugar de "alpine".
#   Es mucho más compatible con los paquetes de Python que necesitan compilación.
FROM python:3.11-slim-bullseye

# 2. Establecemos el directorio de trabajo
WORKDIR /service/app

# 3. Instalamos las dependencias del sistema operativo
#    - 'curl' es necesario para el HEALTHCHECK
#    - 'build-essential' (contiene gcc, make, etc.) es necesario
#      para compilar paquetes de Python (C-extensions)
#    - Limpiamos el caché de 'apt' para mantener la imagen ligera
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 4. Optimizamos el caché de Docker
#    Copiamos *solo* el archivo de requisitos primero
COPY requirements.txt .

# 5. Instalamos las dependencias de Python
#    Esto solo se volverá a ejecutar si 'requirements.txt' cambia.
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# 6. Copiamos el código fuente de nuestra aplicación
#    Esto se volverá a ejecutar cada vez que cambie el código fuente,
#    pero los paquetes de arriba (que tardan más) se mantendrán en caché.
COPY ./src/ .

# 7. Exponemos el puerto de la aplicación
EXPOSE 8081

# 8. Variable de entorno para que Python no guarde logs en buffer
ENV PYTHONUNBUFFERED 1

# 9. Healthcheck (sin cambios, ya estaba bien)
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=5 \
    CMD curl -s --fail http://localhost:8081/health || exit 1

# 10. Comando para correr la app (sin cambios)
#     (Asume que 'app.py' está en la raíz de lo que copiamos desde 'src')
CMD ["python3", "-u", "app.py"]
