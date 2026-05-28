const crypto = require("crypto");
const fs = require("fs");
const express = require("express");
const cors = require("cors");
const path = require("path");
const { all, get, init, run } = require("./database");

const app = express();
const port = Number(process.env.PORT || 3000);
const uploadsDir = path.join(__dirname, "..", "uploads");
fs.mkdirSync(uploadsDir, { recursive: true });

app.set("trust proxy", true);
app.use(cors());
app.use(express.json({ limit: "12mb" }));
app.use(express.static(path.join(__dirname, "..", "public")));
app.use("/uploads", express.static(uploadsDir));

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

function parseJsonRow(row) {
  return JSON.parse(row.json);
}

async function upsertJson(table, id, coupleId, json, extra = {}) {
  if (table === "messages") {
    await run(
      "INSERT OR REPLACE INTO messages (id, couple_id, sent_at, json) VALUES (?, ?, ?, ?)",
      [id, coupleId, json.sentAt || nowISO(), JSON.stringify(json)]
    );
    return;
  }

  if (table === "memories") {
    await run(
      "INSERT OR REPLACE INTO memories (id, couple_id, date, json) VALUES (?, ?, ?, ?)",
      [id, coupleId, json.date || nowISO(), JSON.stringify(json)]
    );
    return;
  }

  if (table === "goals") {
    await run(
      "INSERT OR REPLACE INTO goals (id, couple_id, kind, json) VALUES (?, ?, ?, ?)",
      [id, coupleId, extra.kind || json.kind || "task", JSON.stringify(json)]
    );
    return;
  }

  if (table === "games") {
    await run(
      "INSERT OR REPLACE INTO games (id, couple_id, kind, day_key, json) VALUES (?, ?, ?, ?, ?)",
      [id, coupleId, extra.kind || json.kind || "dailyQuestion", extra.dayKey || json.dayKey || null, JSON.stringify(json)]
    );
  }
}

async function seedGoalsIfNeeded(coupleId) {
  const existing = await get("SELECT id FROM goals WHERE couple_id = ? LIMIT 1", [coupleId]);
  if (existing) {
    return;
  }

  const goals = [
    {
      id: makeId("goal"),
      coupleId,
      title: "Путешествие к морю",
      detail: "Накопить на спокойную поездку на двоих.",
      kind: "savings",
      progress: 0.2,
      targetAmount: 180000,
      currentAmount: 36000,
      dueDate: null,
      isCompleted: false
    },
    {
      id: makeId("goal"),
      coupleId,
      title: "Вечер без телефонов",
      detail: "Приготовить ужин и провести вечер только вдвоем.",
      kind: "task",
      progress: 0,
      targetAmount: null,
      currentAmount: null,
      dueDate: null,
      isCompleted: false
    },
    {
      id: makeId("goal"),
      coupleId,
      title: "Общий wishlist",
      detail: "Добавить идеи подарков и маленьких радостей.",
      kind: "wishlist",
      progress: 0,
      targetAmount: null,
      currentAmount: null,
      dueDate: null,
      isCompleted: false
    }
  ];

  for (const goal of goals) {
    await upsertJson("goals", goal.id, coupleId, goal, { kind: goal.kind });
  }
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function seedGamesIfNeeded(coupleId) {
  const dayKey = todayKey();
  const existing = await get("SELECT id FROM games WHERE couple_id = ? AND day_key = ? LIMIT 1", [coupleId, dayKey]);
  if (existing) {
    return;
  }

  await run("DELETE FROM games WHERE couple_id = ? AND kind = ?", [coupleId, "dailyQuestion"]);

  const dailyPrompts = [
    "Что сегодня заставило тебя улыбнуться из-за партнера?",
    "Какой маленький жест любви ты хочешь сделать сегодня?",
    "За что ты хочешь поблагодарить партнера прямо сейчас?",
    "Какой общий момент недели хочется запомнить?"
  ];
  const index = Math.floor(Date.now() / 86400000) % dailyPrompts.length;
  const games = [
    {
      id: makeId("game"),
      coupleId,
      kind: "dailyQuestion",
      prompt: dailyPrompts[index],
      options: [],
      completedToday: false,
      dayKey,
      answers: []
    },
    {
      id: makeId("game"),
      coupleId,
      kind: "partnerQuiz",
      prompt: "Какой вечер партнер выберет первым?",
      options: ["Кино дома", "Прогулка", "Ресторан", "Игровой вечер"],
      completedToday: false,
      dayKey,
      answers: []
    },
    {
      id: makeId("game"),
      coupleId,
      kind: "romanticTask",
      prompt: "Отправь короткое сообщение с одной причиной, почему тебе тепло рядом.",
      options: [],
      completedToday: false,
      dayKey,
      answers: []
    }
  ];

  for (const game of games) {
    await upsertJson("games", game.id, coupleId, game, { kind: game.kind, dayKey });
  }
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
    avatarURL: user.avatar_url || null,
    partnerAvatarURL: partner?.avatar_url || null,
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

app.get("/health", (_request, response) => {
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
    await seedGoalsIfNeeded(coupleId);
    await seedGamesIfNeeded(coupleId);

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
    await seedGoalsIfNeeded(coupleId);
    await seedGamesIfNeeded(coupleId);

    response.json({ session: await loadSession(user.id), partnerCode: partner.code });
  } catch (error) {
    next(error);
  }
});

app.patch("/api/profile", async (request, response, next) => {
  try {
    const { userId, displayName, partnerName, relationshipStartedAt, avatarURL, partnerAvatarURL } = request.body;
    const session = await loadSession(userId);

    if (!session || !session.coupleId || !session.partnerId) {
      sendError(response, 400, "Сначала нужно связать пару.");
      return;
    }

    await run("UPDATE users SET display_name = ? WHERE id = ?", [displayName || "Вы", userId]);
    await run("UPDATE users SET display_name = ? WHERE id = ?", [partnerName || "Партнер", session.partnerId]);
    if (avatarURL !== undefined) {
      await run("UPDATE users SET avatar_url = ? WHERE id = ?", [avatarURL || null, userId]);
    }
    if (partnerAvatarURL !== undefined) {
      await run("UPDATE users SET avatar_url = ? WHERE id = ?", [partnerAvatarURL || null, session.partnerId]);
    }
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

app.get("/api/couple/:coupleId/data", async (request, response, next) => {
  try {
    const coupleId = request.params.coupleId;
    const couple = await get("SELECT * FROM couples WHERE id = ?", [coupleId]);
    if (!couple) {
      sendError(response, 404, "Пара не найдена.");
      return;
    }

    await seedGoalsIfNeeded(coupleId);
    await seedGamesIfNeeded(coupleId);

    const messages = await all("SELECT json FROM messages WHERE couple_id = ? ORDER BY sent_at ASC", [coupleId]);
    const memories = await all("SELECT json FROM memories WHERE couple_id = ? ORDER BY date DESC", [coupleId]);
    const goals = await all("SELECT json FROM goals WHERE couple_id = ? ORDER BY kind ASC", [coupleId]);
    const games = await all("SELECT json FROM games WHERE couple_id = ? ORDER BY kind ASC", [coupleId]);
    const firstUser = await get("SELECT id, display_name, current_mood, avatar_url FROM users WHERE id = ?", [couple.first_user_id]);
    const secondUser = await get("SELECT id, display_name, current_mood, avatar_url FROM users WHERE id = ?", [couple.second_user_id]);

    response.json({
      messages: messages.map(parseJsonRow),
      memories: memories.map(parseJsonRow),
      goals: goals.map(parseJsonRow),
      games: games.map(parseJsonRow),
      users: [firstUser, secondUser].filter(Boolean).map((user) => ({
        id: user.id,
        displayName: user.display_name,
        currentMood: user.current_mood || "happy",
        avatarURL: user.avatar_url || null
      }))
    });
  } catch (error) {
    next(error);
  }
});

app.post("/api/messages", async (request, response, next) => {
  try {
    const { message } = request.body;
    if (!message?.id || !message?.coupleId) {
      sendError(response, 400, "Сообщение заполнено неверно.");
      return;
    }
    await upsertJson("messages", message.id, message.coupleId, message);
    response.json({ message });
  } catch (error) {
    next(error);
  }
});

app.post("/api/uploads/image", async (request, response, next) => {
  try {
    const { coupleId, imageBase64, fileExtension } = request.body;
    if (!coupleId || !imageBase64) {
      sendError(response, 400, "Фото заполнено неверно.");
      return;
    }

    const couple = await get("SELECT id FROM couples WHERE id = ?", [coupleId]);
    if (!couple) {
      sendError(response, 404, "Пара не найдена.");
      return;
    }

    const extension = String(fileExtension || "jpg").toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
    const fileName = `${makeId("image")}.${extension}`;
    const filePath = path.join(uploadsDir, fileName);
    const imageBuffer = Buffer.from(String(imageBase64), "base64");

    await fs.promises.writeFile(filePath, imageBuffer);

    const protocol = request.get("x-forwarded-proto") || request.protocol;
    const imageURL = `${protocol}://${request.get("host")}/uploads/${fileName}`;
    response.json({ imageURL });
  } catch (error) {
    next(error);
  }
});

app.post("/api/messages/:messageId/reactions", async (request, response, next) => {
  try {
    const row = await get("SELECT json FROM messages WHERE id = ?", [request.params.messageId]);
    if (!row) {
      sendError(response, 404, "Сообщение не найдено.");
      return;
    }

    const message = parseJsonRow(row);
    message.reactions = [...(message.reactions || []), request.body.reaction];
    await upsertJson("messages", message.id, message.coupleId, message);
    response.json({ message });
  } catch (error) {
    next(error);
  }
});

app.delete("/api/messages/:messageId", async (request, response, next) => {
  try {
    await run("DELETE FROM messages WHERE id = ?", [request.params.messageId]);
    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/api/memories", async (request, response, next) => {
  try {
    const { memory } = request.body;
    if (!memory?.id || !memory?.coupleId) {
      sendError(response, 400, "Воспоминание заполнено неверно.");
      return;
    }
    await upsertJson("memories", memory.id, memory.coupleId, memory);
    response.json({ memory });
  } catch (error) {
    next(error);
  }
});

app.patch("/api/memories/:memoryId", async (request, response, next) => {
  try {
    const row = await get("SELECT json FROM memories WHERE id = ?", [request.params.memoryId]);
    if (!row) {
      sendError(response, 404, "Воспоминание не найдено.");
      return;
    }

    const memory = request.body.memory || {
      ...parseJsonRow(row),
      ...request.body
    };
    await upsertJson("memories", memory.id, memory.coupleId, memory);
    response.json({ memory });
  } catch (error) {
    next(error);
  }
});

app.delete("/api/memories/:memoryId", async (request, response, next) => {
  try {
    await run("DELETE FROM memories WHERE id = ?", [request.params.memoryId]);
    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/api/goals", async (request, response, next) => {
  try {
    const { goal } = request.body;
    if (!goal?.id || !goal?.coupleId) {
      sendError(response, 400, "Цель заполнена неверно.");
      return;
    }
    await upsertJson("goals", goal.id, goal.coupleId, goal, { kind: goal.kind });
    response.json({ goal });
  } catch (error) {
    next(error);
  }
});

app.patch("/api/goals/:goalId", async (request, response, next) => {
  try {
    const row = await get("SELECT json FROM goals WHERE id = ?", [request.params.goalId]);
    if (!row) {
      sendError(response, 404, "Цель не найдена.");
      return;
    }

    const existingGoal = parseJsonRow(row);
    const goal = request.body.goal || {
      ...existingGoal,
      progress: request.body.progress ?? existingGoal.progress,
      currentAmount: request.body.currentAmount ?? existingGoal.currentAmount,
      isCompleted: request.body.isCompleted ?? existingGoal.isCompleted
    };
    await upsertJson("goals", goal.id, goal.coupleId, goal, { kind: goal.kind });
    response.json({ goal });
  } catch (error) {
    next(error);
  }
});

app.delete("/api/goals/:goalId", async (request, response, next) => {
  try {
    await run("DELETE FROM goals WHERE id = ?", [request.params.goalId]);
    response.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/api/games/:gameId/answers", async (request, response, next) => {
  try {
    const row = await get("SELECT json FROM games WHERE id = ?", [request.params.gameId]);
    if (!row) {
      sendError(response, 404, "Игра не найдена.");
      return;
    }

    const game = parseJsonRow(row);
    const answer = {
      id: makeId("answer"),
      userId: request.body.userId,
      text: request.body.answer || "",
      createdAt: nowISO()
    };
    game.answers = [...(game.answers || []), answer];
    game.completedToday = true;
    await upsertJson("games", game.id, game.coupleId, game, { kind: game.kind, dayKey: game.dayKey });
    response.json({ game });
  } catch (error) {
    next(error);
  }
});

app.post("/api/mood", async (request, response, next) => {
  try {
    const { userId, mood } = request.body;
    const user = await get("SELECT * FROM users WHERE id = ?", [userId]);
    if (!user) {
      sendError(response, 404, "Пользователь не найден.");
      return;
    }

    await run("UPDATE users SET current_mood = ? WHERE id = ?", [mood || "happy", userId]);
    response.json({ session: await loadSession(userId) });
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
