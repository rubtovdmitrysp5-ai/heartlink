const tabButtons = document.querySelectorAll(".tabbar button");
const screens = document.querySelectorAll(".screen");
const onboarding = document.querySelector("#onboarding");
const auth = document.querySelector("#auth");
const lock = document.querySelector("#lock");
const settingsSheet = document.querySelector("#settingsSheet");
const memorySheet = document.querySelector("#memorySheet");
const toast = document.querySelector("#toast");
const dots = document.querySelectorAll(".dots span");
const onboardingTitle = document.querySelector("#onboardingTitle");
const onboardingText = document.querySelector("#onboardingText");
const onboardingIcon = document.querySelector("#onboardingIcon");
const nextOnboarding = document.querySelector("#nextOnboarding");
const skipOnboarding = document.querySelector("#skipOnboarding");
const loginButton = document.querySelector("#loginButton");
const unlockButton = document.querySelector("#unlockButton");
const unlockByCode = document.querySelector("#unlockByCode");
const closeSettings = document.querySelector("#closeSettings");
const closeMemory = document.querySelector("#closeMemory");
const composer = document.querySelector("#composer");
const messageInput = document.querySelector("#messageInput");
const messages = document.querySelector(".messages");
const counter = document.querySelector(".days-counter");

const onboardingPages = [
  {
    icon: "♡",
    title: "Личное пространство для пары",
    text: "Сообщения, воспоминания, цели и настроение в одном нежном приложении.",
  },
  {
    icon: "◷",
    title: "Каждый день вместе",
    text: "Счётчик отношений, годовщины и общие моменты всегда рядом.",
  },
  {
    icon: "⌂",
    title: "Только для вас двоих",
    text: "Face ID, код-пароль и приватный режим защищают личные истории.",
  },
];

let onboardingIndex = 0;
let toastTimer;

function showScreen(target) {
  screens.forEach((screen) => {
    screen.classList.toggle("active", screen.dataset.screen === target);
  });

  tabButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.target === target);
  });
}

function setOverlay(element, isOpen) {
  element.classList.toggle("active", isOpen);
}

function closeSheets() {
  settingsSheet.classList.remove("active");
  memorySheet.classList.remove("active");
}

function showToast(text) {
  window.clearTimeout(toastTimer);
  toast.textContent = text;
  toast.classList.remove("active");
  void toast.offsetWidth;
  toast.classList.add("active");
  toastTimer = window.setTimeout(() => toast.classList.remove("active"), 1700);
}

function renderOnboarding() {
  const page = onboardingPages[onboardingIndex];
  onboardingIcon.textContent = page.icon;
  onboardingTitle.textContent = page.title;
  onboardingText.textContent = page.text;
  nextOnboarding.textContent = onboardingIndex === onboardingPages.length - 1 ? "Начать" : "Дальше";
  dots.forEach((dot, index) => dot.classList.toggle("active", index === onboardingIndex));
}

function finishOnboarding() {
  setOverlay(onboarding, false);
  setOverlay(auth, true);
}

function openDemoApp() {
  setOverlay(onboarding, false);
  setOverlay(auth, false);
  animateCounter();
}

function animateCounter() {
  const target = Number(counter.dataset.count || 486);
  let value = 0;
  const step = Math.max(1, Math.floor(target / 56));

  const interval = window.setInterval(() => {
    value = Math.min(target, value + step);
    counter.textContent = value.toLocaleString("ru-RU");
    if (value >= target) {
      window.clearInterval(interval);
    }
  }, 18);
}

tabButtons.forEach((button) => {
  button.addEventListener("click", () => {
    closeSheets();
    showScreen(button.dataset.target);
  });
});

nextOnboarding.addEventListener("click", () => {
  if (onboardingIndex === onboardingPages.length - 1) {
    finishOnboarding();
    return;
  }

  onboardingIndex += 1;
  renderOnboarding();
});

skipOnboarding.addEventListener("click", openDemoApp);

loginButton.addEventListener("click", () => {
  setOverlay(auth, false);
  showToast("Вы вошли в HeartLink");
  animateCounter();
});

unlockButton.addEventListener("click", () => {
  setOverlay(lock, false);
  showToast("HeartLink разблокирован");
});

unlockByCode.addEventListener("click", () => {
  setOverlay(lock, false);
  showToast("Код принят");
});

document.querySelectorAll("[data-open-lock]").forEach((button) => {
  button.addEventListener("click", () => {
    closeSheets();
    setOverlay(lock, true);
  });
});

document.querySelectorAll("[data-open-settings]").forEach((button) => {
  button.addEventListener("click", () => {
    closeSheets();
    settingsSheet.classList.add("active");
  });
});

document.querySelectorAll("[data-add-memory]").forEach((button) => {
  button.addEventListener("click", () => {
    closeSheets();
    memorySheet.classList.add("active");
  });
});

document.querySelectorAll("[data-toast]").forEach((button) => {
  button.addEventListener("click", () => showToast(button.dataset.toast));
});

closeSettings.addEventListener("click", () => {
  settingsSheet.classList.remove("active");
  showToast("Код сохранён");
});

closeMemory.addEventListener("click", () => {
  memorySheet.classList.remove("active");
  showToast("Воспоминание добавлено");
});

composer.addEventListener("submit", (event) => {
  event.preventDefault();
  const text = messageInput.value.trim();
  if (!text) {
    showToast("Голосовое сообщение добавлено");
    return;
  }

  const bubble = document.createElement("div");
  bubble.className = "message mine";
  bubble.textContent = text;
  messages.appendChild(bubble);
  messageInput.value = "";
  messages.scrollTop = messages.scrollHeight;
});

document.querySelectorAll(".mood-grid button").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".mood-grid button").forEach((item) => item.classList.remove("selected"));
    button.classList.add("selected");
    showToast(`Настроение: ${button.dataset.mood}`);
  });
});

document.querySelectorAll(".choice-grid button").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".choice-grid button").forEach((item) => item.classList.remove("selected"));
    button.classList.add("selected");
    showToast("Ответ выбран");
  });
});

renderOnboarding();
