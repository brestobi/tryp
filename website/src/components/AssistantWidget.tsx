import { FormEvent, useEffect, useRef, useState } from 'react';
import { Bot, MessageCircle, Send, X } from 'lucide-react';

type Message = { role: 'user' | 'assistant'; content: string };

const welcome: Message = {
  role: 'assistant',
  content: 'Hi! I’m the TRYP assistant. Ask me about rides, driving with TRYP, safety, or support.',
};

export function AssistantWidget() {
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<Message[]>([welcome]);
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (open) inputRef.current?.focus();
  }, [open]);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, loading]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const question = input.trim();
    if (!question || loading) return;

    const nextMessages = [...messages, { role: 'user' as const, content: question }];
    setMessages(nextMessages);
    setInput('');
    setLoading(true);

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: question, history: messages.slice(-10) }),
      });
      const data = await response.json() as { answer?: string; error?: string };
      if (!response.ok) throw new Error(data.error || 'The assistant is unavailable.');
      setMessages([...nextMessages, { role: 'assistant', content: data.answer || 'I could not find an answer.' }]);
    } catch (error) {
      setMessages([...nextMessages, { role: 'assistant', content: error instanceof Error ? error.message : 'Please try again or email hello@tryp.co.za.' }]);
    } finally {
      setLoading(false);
    }
  }

  return <div className="assistant-widget">
    {open && <section className="assistant-panel" aria-label="TRYP AI assistant">
      <header className="assistant-header">
        <div className="assistant-title"><span className="assistant-avatar"><Bot size={18} /></span><span><strong>TRYP assistant</strong><small>Ask about the journey</small></span></div>
        <button className="assistant-close" onClick={() => setOpen(false)} aria-label="Close TRYP assistant"><X size={19} /></button>
      </header>
      <div className="assistant-messages" aria-live="polite">
        {messages.map((message, index) => <div className={`assistant-message ${message.role}`} key={`${message.role}-${index}`}>{message.content}</div>)}
        {loading && <div className="assistant-message assistant typing" aria-label="Assistant is typing"><i /><i /><i /></div>}
        <div ref={endRef} />
      </div>
      <form className="assistant-form" onSubmit={submit}><label className="sr-only" htmlFor="assistant-question">Ask TRYP a question</label><input ref={inputRef} id="assistant-question" value={input} onChange={(event) => setInput(event.target.value)} placeholder="Ask a question…" maxLength={1000} disabled={loading} /><button type="submit" disabled={!input.trim() || loading} aria-label="Send question"><Send size={17} /></button></form>
      <p className="assistant-disclaimer">AI answers are based on confirmed TRYP information. For support: hello@tryp.co.za</p>
    </section>}
    <button className={`assistant-launcher ${open ? 'active' : ''}`} onClick={() => setOpen(!open)} aria-expanded={open} aria-controls="assistant-panel"><span>{open ? <X size={22} /> : <MessageCircle size={22} />}</span><b>{open ? 'Close' : 'Ask TRYP'}</b></button>
  </div>;
}
