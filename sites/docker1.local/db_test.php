<?php
echo "PHP " . PHP_VERSION;

// Script de prueba de conexión a MariaDB

// Variables de conexión
// Utilizamos el nombre del servicio Docker Compose 'mariadb' como HOST.
$host = 'mariadb';
// NOTA: Estas credenciales se leerán desde el archivo .env a través del contenedor PHP-FPM
$dbname = getenv('MARIADB_DATABASE');
$user = getenv('MARIADB_USER');
$password = getenv('MARIADB_PASSWORD');

try {
    // Intentar conexión usando PDO (PHP Data Objects)
    $dsn = "mysql:host=$host;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $user, $password);
    
    // Configurar atributos para manejo de errores
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "<h1>✅ ¡Éxito! Conexión a la base de datos '$dbname' establecida.</h1>";
    
    // Opcional: Ejecutar una consulta simple para verificar la base de datos
    $stmt = $pdo->query('SELECT NOW() AS `current_time`');
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "<p>La hora actual del servidor de base de datos es: <strong>" . $result['current_time'] . "</strong></p>";

} catch (PDOException $e) {
    // Mostrar error si la conexión falla
    echo "<h1>❌ Error de Conexión a la Base de Datos</h1>";
    echo "<p>No se pudo conectar al servidor <strong>$host</strong>.</p>";
    echo "<p>Error: " . $e->getMessage() . "</p>";
    echo "<p>Verifique que el servicio 'mariadb' esté levantado y que las credenciales en el archivo .env sean correctas.</p>";
}
