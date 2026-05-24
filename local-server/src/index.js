const crypto = require("crypto");
const express = require("express");
const cors = require("cors");
const path = require("path");
const { get, init, run } = require("./database");

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, "..", "public")));

function nowISO() {
  return new Date().toISOString();
}

async function generateCode() {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const code = `HL-${Math.floor(100000 + Math.random() * 900000)}`;
    const existing = await get("SELECT id FROM users WHERE code = ?", [code]);
    if (!existing) {
      return code;
    }
  }
  throw new Error("Не удалось создать уникальный код.");
}

function makeId(prefix) {
  return `${prefix}_${crypto.randomUUID()}`;
}

async function createUser(displayName = null) {
  const user = {
    id: makeId("user"),
    code: await generateCode(),
    display_name: displayName,
    couple_id: null,
    created_at: nowISO()
  };

  await run(
    "INSERT INTO users (id, code, display_name, couple_id, created_at) VALUES (?, ?, ?, ?, ?)",
    [user.id, user.code, user.display_name, user.couple_id, user.created_at]
  );

  return user;
}

async function loadSession(userId) {
  const user = await get("SELECT * FROM users WHERE id = ?", [userId]);
  if (!user) {
    return null;
  }

  let couple = null;
  let partner = null;

  if (user.couple_id) {
    couple = await get("SELECT * FROM couples WHERE id = ?", [user.couple_id]);
    if (couple) {
      const partnerId = couple.first_user_id === user.id ? couple.second_user_id : couple.first_user_id;
      partner = await get("SELECT * FROM users WHERE id = ?", [partnerId]);
    }
  }

  return {
    userId: user.id,
    personalCode: user.code,
    coupleId: user.couple_id,
    partnerId: partner?.id || null,
    displayName: user.display_name,
    partnerName: partner?.display_name || null,
    relationshipStartedAt: couple?.started_at || null,
    setupComplete: Boolean(user.display_name && partner?.display_name && couple?.started_at)
  };
}

function sendError(response, status, message) {
  response.status(status).json({
    error: {
      message
    }
  });
}

app.get("/api/health", (_request, response) => {
  response.json({ status: "ok", app: "HeartLink local server" });
});

app.post("/api/session/start", async (_request, response, next) => {
  try {
    const user = await createUser();
    response.json({ session: await loadSession(user.id) });
  } catch (error) {
    next(error);
  }
});

app.get("/api/session/:userId", async (request, response, next) => {
  try {
    const session = await loadSession(request.params.userId);
    if (!session) {
      sendError(response, 404, "Пользователь не найден.");
      return;
    }
    response.json({ session });
  } catch (error) {
    next(error);
  }
});

app.post("/api/pairing/link", async (request, response, next) => {
  try {
    const { userId, partnerCode } = request.body;
    const user = await get("SELECT * FROM users WHERE id = ?", [userId]);
    const partner = await get("SELECT * FROM users WHERE code = ?", [String(partnerCode || "").toUpperCase()]);

    if (!user) {
      sendError(response, 404, "Ваш пользователь не найден.");
      return;
    }

    if (!partner) {
      sendError(response, 404, "Код партнера не найден.");
      return;
    }

    if (partner.id === user.id) {
      sendError(response, 400, "Нельзя ввести собственный код.");
      return;
    }

    if (user.couple_id || partner.couple_id) {
      sendError(response, 409, "Один из пользователей уже связан в пару.");
      return;
    }

    const coupleId = makeId("couple");
    await run(
      "INSERT INTO couples (id, first_user_id, second_user_id, started_at, created_at) VALUES (?, ?, ?, ?, ?)",
      [coupleId, user.id, partner.id, null, nowISO()]
    );
    await run("UPDATE users SET couple_id = ? WHERE id IN (?, ?)", [coupleId, user.id, partner.id]);

    response.json({ session: await loadSession(user.id) });
  } catch (error) {
    next(error);
  }
});

app.post("/api/dev/create-test-partner", async (request, response, next) => {
  try {
    const { userId } = request.body;
    const user = await get("SELECT * FROM users WHERE id = ?", [userId]);

    if (!user) {
      sendError(response, 404, "Ваш пользователь не найден.");
      return;
    }

    if (user.couple_id) {
      response.json({ session: await loadSession(user.id) });
      return;
    }

    const partner = await createUser("Тестовый партнер");
    const coupleId = makeId("couple");

    await run(
      "INSERT INTO couples (id, first_user_id, second_user_id, started_at, created_at) VALUES (?, ?, ?, ?, ?)",
      [coupleId, user.id, partner.id, null, nowISO()]
    );
    await run("UPDATE users SET couple_id = ? WHERE id IN (?, ?)", [coupleId, user.id, partner.id]);

    response.json({ session: await loadSession(user.id), partnerCode: partner.code });
  } catch (error) {
    next(error);
  }
});

app.patch("/api/profile", async (request, response, next) => {
  try {
    const { userId, displayName, partnerName, relationshipStartedAt } = request.body;
    const session = await loadSession(userId);

    if (!session || !session.coupleId || !session.partnerId) {
      sendError(response, 400, "Сначала нужно связать пару.");
      return;
    }

    await run("UPDATE users SET display_name = ? WHERE id = ?", [displayName || "Вы", userId]);
    await run("UPDATE users SET display_name = ? WHERE id = ?", [partnerName || "Партнер", session.partnerId]);
    await run("UPDATE couples SET started_at = ? WHERE id = ?", [relationshipStartedAt || nowISO(), session.coupleId]);

    response.json({ session: await loadSession(userId) });
  } catch (error) {
    next(error);
  }
});

app.get("/api/couple/:coupleId", async (request, response, next) => {
  try {
    const couple = await get("SELECT * FROM couples WHERE id = ?", [request.params.coupleId]);
    if (!couple) {
      sendError(response, 404, "Пара не найдена.");
      return;
    }
    response.json({ couple });
  } catch (error) {
    next(error);
  }
});

app.use((error, _request, response, _next) => {
  console.error(error);
  sendError(response, 500, "Ошибка локального сервера.");
});

init().then(() => {
  app.listen(port, "0.0.0.0", () => {
    console.log(`HeartLink local server: http://localhost:${port}`);
    console.log(`Test panel: http://localhost:${port}/`);
  });
});
