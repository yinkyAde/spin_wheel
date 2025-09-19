# Spin Wheel – Flutter Web (Center-Locked)

A tiny, fun **spin wheel** game built with Flutter.  
It’s **simple for anyone** to use, **responsive** on phones/desktops, and always stops **exactly on the center** of the winning wedge (no “between” landings).

Live demo: **https://yinkyade.github.io/flutter-spin-wheel-app/**

---

## ✨ Features

- **One-tap gameplay** – big wheel + one **SPIN** button.
- **Center-locked landing** – the pointer snaps to the *exact* center of the selected wedge.
- **Risk vs reward** – a **Death** wedge replaces the smallest prizes *in place*.  
  More Death = fewer small wins → higher stakes.
- **Haptics on Death** – heavy vibration to dramatize the loss (mobile devices).
- **Responsive layout** – scales beautifully from phones to desktops.
- **No external packages** – pure Flutter + Material.

> By default at least **one Death wedge** is always present (you can raise the count, but not drop below 1).

---

## 🕹️ Gameplay

- Tap **SPIN** to spin the wheel.
- The result is **locked at spin start** and shown after the animation.
- If it hits **Death**, you’ll feel a **strong haptic** (on supported devices) and see an “Uh-oh!” message.

---

## ⚙️ How “Death” Works

Base prize tiers are ordered **small → big**.  
When you increase the Death counter:

- The **smallest prize** is **replaced in place** by a **Death** wedge.
- That Death wedge **inherits the same weight** (probability) as the removed prize.
- Remaining prizes keep their relative positions; angles stay consistent.

This makes the game **riskier** while keeping the wheel fair and predictable.


