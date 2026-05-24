# HeartLink Local Server

Временный локальный backend для тестирования связывания пары по кодам на Windows.

## Запуск на Windows

1. Установите Node.js LTS: https://nodejs.org/
2. Откройте PowerShell в папке проекта.
3. Выполните:

```powershell
cd local-server
npm install
npm start
```

Сервер запустится на:

```text
http://localhost:3000
```

Тестовая страница:

```text
http://localhost:3000
```

## Как подключить iPhone

ПК и iPhone должны быть в одной Wi-Fi сети.

1. Узнайте IP компьютера:

```powershell
ipconfig
```

2. Найдите IPv4 адрес, например:

```text
192.168.1.45
```

3. В приложении HeartLink укажите адрес сервера:

```text
http://192.168.1.45:3000
```

Если iPhone не видит ПК, временно разрешите Node.js в Windows Firewall или используйте туннель ngrok/cloudflared.

## Тест без второго iPhone

В приложении нажмите:

```text
Создать тестового партнера
```

Сервер создаст второго пользователя и сразу свяжет его с вашим iPhone.
