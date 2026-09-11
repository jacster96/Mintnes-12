@'
"use client";

import { useState, useRef, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

interface Message {
  role: "user" | "assistant";
  content: string;
  image?: string;
}

interface Chat {
  id: string;
  title: string;
  messages: Message[];
  createdAt: number;
}

const ACCENT_COLORS = ["#059669", "#2563eb", "#dc2626", "#7c3aed", "#ea580c", "#0891b2"];

function MicIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
      <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
    </svg>
  );
}

function PlusIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  );
}

function SettingsIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  );
}

function PaletteIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="13.5" cy="6.5" r=".5" fill="currentColor" />
      <circle cx="17.5" cy="10.5" r=".5" fill="currentColor" />
      <circle cx="8.5" cy="7.5" r=".5" fill="currentColor" />
      <circle cx="6.5" cy="12.5" r=".5" fill="currentColor" />
      <path d="M12 2a10 10 0 1 0 10 10c0-1.1-.9-2-2-2h-1a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.5a1 1 0 0 0 0-2A9.94 9.94 0 0 0 12 2z" />
    </svg>
  );
}

function FolderIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
    </svg>
  );
}

function handleAttachClick(
    userEmail: string | null,
    fileInputRef: React.RefObject<HTMLInputElement>,
    router: ReturnType<typeof useRouter>
  ) {
    if (!userEmail) {
      alert("Image bhejne ke liye pehle login karo.");
      router.push("/login");
      return;
    }
    fileInputRef.current?.click();
  }

export default function Home() {
  const router = useRouter();
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [authChecked, setAuthChecked] = useState(false);
  const [theme, setTheme] = useState<"dark" | "light">("dark");
  const [accent, setAccent] = useState(ACCENT_COLORS[0]);
  const [input, setInput] = useState("");
  const [chats, setChats] = useState<Chat[]>([]);
  const [activeChatId, setActiveChatId] = useState<string | null>(null);
  const [autoLoop, setAutoLoop] = useState(false);
  const [loading, setLoading] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [isListening, setIsListening] = useState(false);
  const [attachedImage, setAttachedImage] = useState<string | null>(null);
  const [uploadProgress, setUploadProgress] = useState<number | null>(null);
  const [customizeOpen, setCustomizeOpen] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const recognitionRef = useRef<any>(null);

  const activeChat = chats.find((c) => c.id === activeChatId) || null;
  const messages = activeChat?.messages || [];

  useEffect(() => {
    const savedTheme = localStorage.getItem("mintnes-theme");
    if (savedTheme === "light" || savedTheme === "dark") setTheme(savedTheme);

    const savedAccent = localStorage.getItem("mintnes-accent");
    if (savedAccent) setAccent(savedAccent);

    const savedChats = localStorage.getItem("mintnes-chats");
    if (savedChats) {
      try {
        setChats(JSON.parse(savedChats));
      } catch {}
    }

    if (typeof window !== "undefined") {
      const SpeechRecognition =
        (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
      if (SpeechRecognition) {
        const recognition = new SpeechRecognition();
        recognition.continuous = false;
        recognition.interimResults = false;
        recognition.lang = "en-US";

        recognition.onresult = (event: any) => {
          const transcript = event.results[0][0].transcript;
          setInput((prev) => (prev ? prev + " " + transcript : transcript));
        };

        recognition.onend = () => setIsListening(false);
        recognition.onerror = () => setIsListening(false);

        recognitionRef.current = recognition;
      }
    }
  }, []);

  useEffect(() => {
    localStorage.setItem("mintnes-theme", theme);
  }, [theme]);

  useEffect(() => {
    localStorage.setItem("mintnes-accent", accent);
  }, [accent]);

  useEffect(() => {
    if (chats.length > 0) {
      localStorage.setItem("mintnes-chats", JSON.stringify(chats));
    }
  }, [chats]);

  useEffect(() => {
    scrollRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, loading]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) setUserEmail(session.user.email ?? null);
      setAuthChecked(true);
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setUserEmail(session?.user.email ?? null);
    });

    return () => listener.subscription.unsubscribe();
  }, [router]);

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push("/login");
  }

  const isDark = theme === "dark";

  function newChat() {
    setActiveChatId(null);
    setSidebarOpen(false);
  }

  function loadChat(id: string) {
    setActiveChatId(id);
    setSidebarOpen(false);
  }

  function deleteChat(id: string, e: React.MouseEvent) {
    e.stopPropagation();
    const updated = chats.filter((c) => c.id !== id);
    setChats(updated);
    localStorage.setItem("mintnes-chats", JSON.stringify(updated));
    if (activeChatId === id) setActiveChatId(null);
  }

  function toggleVoice() {
    if (!recognitionRef.current) {
      alert("Voice input aapke browser mein support nahi hai. Chrome try karo.");
      return;
    }
    if (isListening) {
      recognitionRef.current.stop();
      setIsListening(false);
    } else {
      recognitionRef.current.start();
      setIsListening(true);
    }
  }

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      alert("Sirf image files allowed hain.");
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      // Simulate realistic upload duration based on file size (like ChatGPT)
      const durationMs = Math.min(Math.max(file.size / 4000, 400), 3500);
      const steps = 20;
      let step = 0;
      setUploadProgress(0);
      const interval = setInterval(() => {
        step++;
        setUploadProgress(Math.min(100, Math.round((step / steps) * 100)));
        if (step >= steps) {
          clearInterval(interval);
          setUploadProgress(null);
          setAttachedImage(result);
        }
      }, durationMs / steps);
    };
    reader.readAsDataURL(file);
  }

  async function sendMessage() {
    if ((!input.trim() && !attachedImage) || loading) return;

    const userMsg: Message = {
      role: "user",
      content: input || "(image attached)",
      ...(attachedImage ? { image: attachedImage } : {}),
    };
    const isNewChat = !activeChatId;
    const chatId = activeChatId || Date.now().toString();
    const currentMessages = isNewChat ? [userMsg] : [...messages, userMsg];

    if (isNewChat) {
      const newChatObj: Chat = {
        id: chatId,
        title: input.slice(0, 40) || "Image chat",
        messages: currentMessages,
        createdAt: Date.now(),
      };
      setChats((prev) => [newChatObj, ...prev]);
      setActiveChatId(chatId);
    } else {
      setChats((prev) =>
        prev.map((c) => (c.id === chatId ? { ...c, messages: currentMessages } : c))
      );
    }

    setInput("");
    setAttachedImage(null);
    setLoading(true);

    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: currentMessages.map((m) => ({
            role: m.role,
            content: m.content,
            ...(m.image ? { image: m.image } : {}),
          })),
          autoLoop,
        }),
      });

      const data = await res.json();
      let assistantContent = "";

      if (data.error) {
        assistantContent = `Error: ${data.error}`;
      } else {
        // Combine all auto-loop steps into one continuous, natural answer
        assistantContent = data.steps
          .map((step: { answer: string }) => step.answer)
          .join("\n\n")
          .trim();
      }

      const finalMessages: Message[] = [
        ...currentMessages,
        { role: "assistant", content: assistantContent },
      ];

      setChats((prev) =>
        prev.map((c) => (c.id === chatId ? { ...c, messages: finalMessages } : c))
      );
    } catch {
      const finalMessages: Message[] = [
        ...currentMessages,
        { role: "assistant", content: "Network error occurred. Check your connection and try again." },
      ];
      setChats((prev) =>
        prev.map((c) => (c.id === chatId ? { ...c, messages: finalMessages } : c))
      );
    } finally {
      setLoading(false);
    }
  }

  const isEmpty = messages.length === 0;

  if (!authChecked) {
    return (
      <div className="flex h-screen items-center justify-center bg-neutral-950 text-neutral-500 text-sm">
        Loading...
      </div>
    );
  }

  const CustomizeModal = () =>
    customizeOpen ? (
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={() => setCustomizeOpen(false)}>
        <div
          onClick={(e) => e.stopPropagation()}
          className={`w-72 rounded-2xl p-4 border ${isDark ? "bg-neutral-900 border-neutral-700" : "bg-white border-neutral-200"}`}
        >
          <h3 className="text-sm font-semibold mb-3">Customize Mintnes</h3>
          <p className={`text-xs mb-3 ${isDark ? "text-neutral-500" : "text-neutral-500"}`}>Accent color</p>
          <div className="flex gap-2 flex-wrap">
            {ACCENT_COLORS.map((c) => (
              <button
                key={c}
                onClick={() => {
                  setAccent(c);
                  setCustomizeOpen(false);
                }}
                style={{ backgroundColor: c }}
                className={`w-8 h-8 rounded-full transition ${accent === c ? "ring-2 ring-offset-2 ring-neutral-400" : ""}`}
              />
            ))}
          </div>
        </div>
      </div>
    ) : null;

  return (
    <div className={`flex h-screen overflow-hidden ${isDark ? "bg-neutral-950 text-neutral-100" : "bg-neutral-50 text-neutral-900"}`}>
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-20 md:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <CustomizeModal />

      {/* Sidebar - monochrome */}
      <aside
        className={`fixed md:static z-30 h-full w-64 flex flex-col transition-transform duration-200 border-r ${
          isDark ? "bg-black border-neutral-800" : "bg-white border-neutral-200"
        } ${sidebarOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"}`}
      >
        <div className="p-3 space-y-1">
          <button
            onClick={newChat}
            className={`w-full flex items-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium transition border ${
              isDark
                ? "bg-white text-black border-white hover:bg-neutral-200"
                : "bg-black text-white border-black hover:bg-neutral-800"
            }`}
          >
            <PlusIcon />
            New chat
          </button>
          <button
            onClick={() => alert("Projects — coming soon")}
            className={`w-full flex items-center gap-2 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
              isDark ? "text-neutral-300 hover:bg-neutral-900" : "text-neutral-700 hover:bg-neutral-100"
            }`}
          >
            <FolderIcon />
            Projects
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-2 space-y-1">
          {chats.length === 0 && (
            <p className={`text-xs px-3 py-2 ${isDark ? "text-neutral-600" : "text-neutral-400"}`}>
              No chats yet
            </p>
          )}
          {chats.map((chat) => (
            <div
              key={chat.id}
              onClick={() => loadChat(chat.id)}
              className={`group flex items-center justify-between gap-2 rounded-lg px-3 py-2 text-sm cursor-pointer transition ${
                chat.id === activeChatId
                  ? isDark
                    ? "bg-neutral-800"
                    : "bg-neutral-200"
                  : isDark
                  ? "hover:bg-neutral-900"
                  : "hover:bg-neutral-100"
              }`}
            >
              <span className="truncate flex-1">{chat.title}</span>
              <button
                onClick={(e) => deleteChat(chat.id, e)}
                className={`opacity-0 group-hover:opacity-100 text-xs shrink-0 ${
                  isDark ? "text-neutral-500 hover:text-neutral-200" : "text-neutral-400 hover:text-neutral-900"
                }`}
              >
                ✕
              </button>
            </div>
          ))}
        </div>

        <div className={`p-2 border-t ${isDark ? "border-neutral-800" : "border-neutral-200"}`}>
          {userEmail && (
            <div className={`px-3 py-2 text-xs truncate ${isDark ? "text-neutral-500" : "text-neutral-400"}`}>
              {userEmail}
            </div>
          )}
          <div className="flex items-center gap-1">
            <button
              onClick={() => setCustomizeOpen(true)}
              className={`flex-1 flex items-center gap-2 rounded-lg px-3 py-2 text-xs font-medium transition ${
                isDark ? "text-neutral-300 hover:bg-neutral-900" : "text-neutral-700 hover:bg-neutral-100"
              }`}
            >
              <PaletteIcon />
              Customize
            </button>
            <button
              onClick={() => alert("Settings — coming soon")}
              className={`w-9 h-9 flex items-center justify-center rounded-lg transition ${
                isDark ? "text-neutral-300 hover:bg-neutral-900" : "text-neutral-700 hover:bg-neutral-100"
              }`}
              aria-label="Settings"
            >
              <SettingsIcon />
            </button>
          </div>
          <button
            onClick={() => (userEmail ? handleLogout() : router.push("/login"))}
            className={`w-full text-left px-3 py-2 rounded-lg text-xs font-medium transition ${
              isDark ? "text-neutral-400 hover:bg-neutral-900 hover:text-red-400" : "text-neutral-500 hover:bg-neutral-100 hover:text-red-500"
            }`}
          >
            {userEmail ? "Logout" : "Login"}
          </button>
        </div>
      </aside>

      <main className="flex-1 flex flex-col min-w-0">
        <header
          className={`flex items-center justify-between px-4 md:px-6 py-3 border-b ${
            isDark ? "border-neutral-800" : "border-neutral-200"
          }`}
        >
          <div className="flex items-center gap-3">
            <button
              onClick={() => setSidebarOpen(true)}
              className={`md:hidden w-9 h-9 flex items-center justify-center rounded-lg ${
                isDark ? "bg-neutral-800" : "bg-neutral-200"
              }`}
            >
              ☰
            </button>
            <h1 className="text-lg md:text-xl font-semibold tracking-tight">Mintnes</h1>
          </div>

          <div className="flex items-center gap-3 md:gap-4">
            <label className="flex items-center gap-2 text-xs md:text-sm cursor-pointer select-none">
              <span className={`hidden sm:inline ${isDark ? "text-neutral-300" : "text-neutral-600"}`}>
                AUTO-LOOP
              </span>
              <button
                type="button"
                role="switch"
                aria-checked={autoLoop}
                onClick={() => setAutoLoop((prev) => !prev)}
                style={{ backgroundColor: autoLoop ? accent : undefined }}
                className={`w-10 h-5 rounded-full relative transition-colors duration-200 shrink-0 ${
                  !autoLoop ? (isDark ? "bg-neutral-700" : "bg-neutral-300") : ""
                }`}
              >
                <span
                  className={`absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white transition-transform duration-200 ${
                    autoLoop ? "translate-x-5" : "translate-x-0"
                  }`}
                />
              </button>
            </label>

            <button
              onClick={() => setTheme(isDark ? "light" : "dark")}
              className={`w-9 h-9 flex items-center justify-center rounded-full text-sm transition-colors shrink-0 ${
                isDark ? "bg-neutral-800 hover:bg-neutral-700" : "bg-neutral-200 hover:bg-neutral-300"
              }`}
              aria-label="Toggle theme"
            >
              {isDark ? "☀️" : "🌙"}
            </button>
          </div>
        </header>

        {isEmpty ? (
          <div className="flex-1 flex flex-col items-center justify-center px-4">
            <h2 className="text-2xl md:text-3xl font-semibold mb-2 text-center">
              Say Goodbye to Wait Times. Meet Our AI Chatbot.
            </h2>
            <p className={`text-sm mb-8 text-center ${isDark ? "text-neutral-500" : "text-neutral-500"}`}>
              Fast, direct, high-leverage jawab
            </p>

            <div className="w-full max-w-2xl">
              {uploadProgress !== null && (
                <div className={`mb-2 h-1.5 w-32 rounded-full overflow-hidden ${isDark ? "bg-neutral-800" : "bg-neutral-200"}`}>
                  <div
                    className="h-full transition-all duration-100"
                    style={{ width: `${uploadProgress}%`, backgroundColor: accent }}
                  />
                </div>
              )}
              {attachedImage && (
                <div className="mb-2 relative inline-block">
                  <img src={attachedImage} alt="attached" className="h-16 rounded-lg border border-neutral-600" />
                  <button
                    onClick={() => setAttachedImage(null)}
                    className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-red-500 text-white text-xs flex items-center justify-center"
                  >
                    ✕
                  </button>
                </div>
              )}
              <div className="flex gap-2 items-center">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleFileSelect}
                  className="hidden"
                />
                <button
                  onClick={() => handleAttachClick(userEmail, fileInputRef, router)}
                  className={`w-9 h-9 flex items-center justify-center rounded-full shrink-0 transition ${
                    isDark ? "bg-neutral-900 border border-neutral-700 hover:bg-neutral-800" : "bg-white border border-neutral-300 hover:bg-neutral-100"
                  }`}
                  aria-label="Attach image"
                >
                  <PlusIcon />
                </button>
                <input
                  autoFocus
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && sendMessage()}
                  placeholder="Message Mintnes..."
                  className={`flex-1 rounded-xl px-4 py-3.5 text-sm focus:outline-none focus:ring-2 ${
                    isDark
                      ? "bg-neutral-900 border border-neutral-700 text-white placeholder-neutral-500"
                      : "bg-white border border-neutral-300 text-neutral-900 placeholder-neutral-400"
                  }`}
                  style={{ ["--tw-ring-color" as any]: accent }}
                />
                <button
                  onClick={toggleVoice}
                  className={`w-9 h-9 flex items-center justify-center rounded-full shrink-0 transition ${
                    isListening
                      ? "bg-red-500 text-white animate-pulse"
                      : isDark
                      ? "bg-neutral-900 border border-neutral-700 hover:bg-neutral-800"
                      : "bg-white border border-neutral-300 hover:bg-neutral-100"
                  }`}
                  aria-label="Voice input"
                >
                  <MicIcon />
                </button>
                <button
                  onClick={sendMessage}
                  disabled={loading}
                  style={{ backgroundColor: accent }}
                  className="hover:opacity-90 disabled:opacity-50 text-white px-6 py-3.5 rounded-xl text-sm font-medium transition shrink-0"
                >
                  Send
                </button>
              </div>
              <p className={`text-center text-xs mt-3 ${isDark ? "text-neutral-600" : "text-neutral-400"}`}>
                Mintnes AI can make mistakes. Please double check for better response.
              </p>
            </div>
          </div>
        ) : (
          <>
            <div className="flex-1 overflow-y-auto px-4 md:px-6 py-6 space-y-4">
              <div className="max-w-3xl mx-auto space-y-4">
                {messages.map((m, i) => (
                  <div
                    key={i}
                    style={m.role === "user" ? { backgroundColor: accent } : undefined}
                    className={`w-fit max-w-[85%] md:max-w-2xl rounded-2xl px-4 py-3 whitespace-pre-wrap text-sm leading-relaxed ${
                      m.role === "user"
                        ? "ml-auto text-white"
                        : isDark
                        ? "mr-auto bg-neutral-900 text-neutral-100 border border-neutral-800"
                        : "mr-auto bg-white text-neutral-900 border border-neutral-200 shadow-sm"
                    }`}
                  >
                    {m.image && (
                      <img src={m.image} alt="attached" className="rounded-lg mb-2 max-h-48" />
                    )}
                    {m.content}
                  </div>
                ))}

                {loading && (
                  <div
                    className={`mr-auto w-fit rounded-2xl px-4 py-3 text-sm flex items-center gap-2 ${
                      isDark
                        ? "bg-neutral-900 text-neutral-400 border border-neutral-800"
                        : "bg-white text-neutral-500 border border-neutral-200"
                    }`}
                  >
                    <span className="w-2 h-2 rounded-full animate-bounce" style={{ backgroundColor: accent }} />
                    <span className="w-2 h-2 rounded-full animate-bounce [animation-delay:0.15s]" style={{ backgroundColor: accent }} />
                    <span className="w-2 h-2 rounded-full animate-bounce [animation-delay:0.3s]" style={{ backgroundColor: accent }} />
                  </div>
                )}
                <div ref={scrollRef} />
              </div>
            </div>

            <div className={`border-t p-3 md:p-4 ${isDark ? "border-neutral-800" : "border-neutral-200"}`}>
              <div className="max-w-3xl mx-auto">
                {uploadProgress !== null && (
                  <div className={`mb-2 h-1.5 w-32 rounded-full overflow-hidden ${isDark ? "bg-neutral-800" : "bg-neutral-200"}`}>
                    <div
                      className="h-full transition-all duration-100"
                      style={{ width: `${uploadProgress}%`, backgroundColor: accent }}
                    />
                  </div>
                )}
                {attachedImage && (
                  <div className="mb-2 relative inline-block">
                    <img src={attachedImage} alt="attached" className="h-16 rounded-lg border border-neutral-600" />
                    <button
                      onClick={() => setAttachedImage(null)}
                      className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-red-500 text-white text-xs flex items-center justify-center"
                    >
                      ✕
                    </button>
                  </div>
                )}
                <div className="flex gap-2 items-center">
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    onChange={handleFileSelect}
                    className="hidden"
                  />
                  <button
                    onClick={() => handleAttachClick(userEmail, fileInputRef, router)}
                    className={`w-9 h-9 flex items-center justify-center rounded-full shrink-0 transition ${
                      isDark ? "bg-neutral-900 border border-neutral-700 hover:bg-neutral-800" : "bg-white border border-neutral-300 hover:bg-neutral-100"
                    }`}
                    aria-label="Attach image"
                  >
                    <PlusIcon />
                  </button>
                  <input
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && sendMessage()}
                    placeholder="Message Mintnes..."
                    className={`flex-1 rounded-xl px-4 py-3 text-sm focus:outline-none focus:ring-2 ${
                      isDark
                        ? "bg-neutral-900 border border-neutral-700 text-white placeholder-neutral-500"
                        : "bg-white border border-neutral-300 text-neutral-900 placeholder-neutral-400"
                    }`}
                  />
                  <button
                    onClick={toggleVoice}
                    className={`w-9 h-9 flex items-center justify-center rounded-full shrink-0 transition ${
                      isListening
                        ? "bg-red-500 text-white animate-pulse"
                        : isDark
                        ? "bg-neutral-900 border border-neutral-700 hover:bg-neutral-800"
                        : "bg-white border border-neutral-300 hover:bg-neutral-100"
                    }`}
                    aria-label="Voice input"
                  >
                    <MicIcon />
                  </button>
                  <button
                    onClick={sendMessage}
                    disabled={loading}
                    style={{ backgroundColor: accent }}
                    className="hover:opacity-90 disabled:opacity-50 text-white px-5 md:px-6 py-3 rounded-xl text-sm font-medium transition shrink-0"
                  >
                    Send
                  </button>
                </div>
                <p className={`text-center text-xs mt-2 ${isDark ? "text-neutral-600" : "text-neutral-400"}`}>
                  Mintnes AI can make mistakes. Please double check for better response.
                </p>
              </div>
            </div>
          </>
        )}
      </main>
    </div>
  );
}
'@ | Set-Content -Path 'src\app\page.tsx' -Encoding UTF8
Write-Host 'page.tsx updated successfully' -ForegroundColor Green
