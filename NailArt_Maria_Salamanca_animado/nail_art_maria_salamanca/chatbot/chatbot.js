/* Asistente virtual de Nail Art María Salamanca
   Usa los servicios y precios reales de app.js (variable global `data`),
   así que si cambias precios allá, el chatbot se actualiza solo. */
(function () {
  // ====== EDITA ESTOS DATOS DEL NEGOCIO ======
  const CONFIG = {
    telefono: "300 000 0000",
    whatsapp: "300 000 0000",
    direccion: "Dirección del local (por definir)",
    horario: "Lunes a sábado, 9:00 a.m. a 6:00 p.m."
  };
  // ===========================================

  const $ = s => document.querySelector(s);
  const box = $("#chatbotMessages"), win = $("#chatbotWindow");
  const fmt = n => new Intl.NumberFormat("es-CO", { style: "currency", currency: "COP", maximumFractionDigits: 0 }).format(n);
  const norm = t => t.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const services = () => (typeof data !== "undefined" ? data.services : []);

  function add(text, who) {
    const d = document.createElement("div");
    d.className = who === "user" ? "user-message" : "bot-message";
    d.textContent = text;
    box.appendChild(d);
    box.scrollTop = box.scrollHeight;
    return d;
  }
  function botSay(text, after) {
    const t = document.createElement("div");
    t.className = "bot-message typing";
    t.innerHTML = "<i></i><i></i><i></i>";
    box.appendChild(t); box.scrollTop = box.scrollHeight;
    setTimeout(() => { t.remove(); add(text, "bot"); if (after) after(); }, 450);
  }
  function goBooking() {
    if (typeof go === "function") go("agendar");
    if (window.innerWidth < 760) win.classList.remove("open");
  }

  const answers = {
    servicios: () => "Estos son nuestros servicios:\n\n" +
      services().map(s => `${s.icon} ${s.name} (${s.duration} min)`).join("\n") +
      "\n\nTambién puedes verlos en la sección Servicios.",
    precios: () => "Precios de referencia:\n\n" +
      services().map(s => `• ${s.name}: ${fmt(s.price)}`).join("\n") +
      "\n\nLos valores pueden variar según el diseño elegido.",
    citas: () => "¡Con gusto! Te llevo al formulario para agendar tu cita 💗\nElige servicio, fecha y hora. Quedará en estado Pendiente hasta que el negocio la confirme.",
    preguntas: () => "Preguntas frecuentes:\n\n" +
      "• ¿Cuánto dura un servicio? Entre 30 y 120 minutos según el tratamiento.\n" +
      "• ¿Mi cita queda confirmada al instante? No, queda Pendiente hasta que el negocio la confirme.\n" +
      "• ¿Puedo llevar una idea de diseño? Sí, cuéntala en las notas al agendar.\n" +
      "• ¿Puedo cancelar? Sí, comunícate con el negocio con anticipación.",
    horario: () => `🕘 Horario de atención:\n${CONFIG.horario}`,
    contacto: () => `📍 ${CONFIG.direccion}\n📞 ${CONFIG.telefono}\n💬 WhatsApp: ${CONFIG.whatsapp}\n🕘 ${CONFIG.horario}`,
    saludo: () => "¡Hola! 💗 ¿En qué puedo ayudarte? Elige una opción o escríbeme tu pregunta.",
    gracias: () => "¡Con mucho gusto! Aquí estaré si necesitas algo más 💅",
    nodata: () => "No estoy segura de haber entendido 🙈\nPuedo ayudarte con servicios, precios, horarios, agendar una cita o contacto. Elige una opción del menú."
  };

  function serviceMatch(q) {
    return services().find(s => {
      const words = norm(s.name).split(/\s+/).filter(w => w.length > 4);
      return words.some(w => q.includes(w.slice(0, -1)));
    });
  }

  function reply(key) {
    if (key === "citas") return botSay(answers.citas(), goBooking);
    botSay(answers[key]());
  }

  function interpret(text) {
    const q = norm(text);
    if (/\b(hola|buenas|buenos|hey|saludos)\b/.test(q)) return "saludo";
    if (/(gracias|genial|perfecto|listo)/.test(q)) return "gracias";
    if (/(precio|cuesta|cuanto|valor|tarifa|costo)/.test(q)) {
      const s = serviceMatch(q);
      if (s) return { custom: `${s.name}: ${fmt(s.price)} · duración aprox. ${s.duration} min.` };
      return "precios";
    }
    if (/(cita|agendar|reserv|turno|apartar)/.test(q)) return "citas";
    if (/(horario|hora de|abren|cierran|atienden|abierto)/.test(q)) return "horario";
    if (/(contacto|telefono|whatsapp|direccion|ubicacion|donde|llamar)/.test(q)) return "contacto";
    if (/(servicio|ofrecen|hacen|catalogo)/.test(q)) return "servicios";
    if (/(pregunta|frecuente|duda|cancel)/.test(q)) return "preguntas";
    const s = serviceMatch(q);
    if (s) return { custom: `${s.icon} ${s.name}: ${s.description}\nPrecio: ${fmt(s.price)} · ${s.duration} min.` };
    return "nodata";
  }

  function handle(text) {
    add(text, "user");
    const r = interpret(text);
    if (typeof r === "object") botSay(r.custom); else reply(r);
  }

  $("#chatbotToggle").addEventListener("click", () => {
    win.classList.toggle("open");
    if (win.classList.contains("open")) $("#chatbotText").focus();
  });
  $("#chatbotClose").addEventListener("click", () => win.classList.remove("open"));
  $("#chatbotOptions").addEventListener("click", e => {
    const b = e.target.closest("[data-option]");
    if (!b) return;
    add(b.textContent, "user");
    reply(b.dataset.option);
  });
  $("#chatbotForm").addEventListener("submit", e => {
    e.preventDefault();
    const input = $("#chatbotText"), v = input.value.trim();
    if (!v) return;
    input.value = "";
    handle(v);
  });
})();
