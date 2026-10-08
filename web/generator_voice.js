/* Capture is requested only by the Dictate button after user consent. */
(() => {
  let session = null;
  const release = (s) => { s.stream?.getTracks().forEach(t => t.stop()); s.context?.close().catch(() => {}); };
  window.lectorVoice = {
    get supported() { return !!(window.isSecureContext && navigator.mediaDevices?.getUserMedia && window.MediaRecorder && (window.AudioContext || window.webkitAudioContext)); },
    async start() {
      this.cancel();
      const s = { chunks: [], cancelled: false, started: Date.now() };
      session = s;
      try {
        s.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        if (s.cancelled) { release(s); return; }
        s.context = new (window.AudioContext || window.webkitAudioContext)();
        // Decoding needs no playback. Resuming after the microphone permission
        // prompt can wait for another gesture on Safari and block recording.
        const types = ['audio/mp4', 'audio/webm;codecs=opus', 'audio/webm'];
        const type = types.find(t => MediaRecorder.isTypeSupported(t));
        s.recorder = new MediaRecorder(s.stream, type ? { mimeType: type } : {});
        s.recorder.ondataavailable = e => { if (e.data.size) s.chunks.push(e.data); };
        s.stopped = new Promise((resolve, reject) => { s.recorder.onstop = resolve; s.recorder.onerror = () => reject(new Error('Enregistrement indisponible.')); });
        s.recorder.start();
        s.timer = setTimeout(() => { if (s.recorder.state !== 'inactive') s.recorder.stop(); s.stream.getTracks().forEach(t => t.stop()); }, 60000);
      } catch (e) { release(s); if (session === s) session = null; throw e; }
    },
    async finish() {
      const s = session;
      if (!s || s.cancelled || !s.recorder) throw new Error('Aucun enregistrement.');
      clearTimeout(s.timer);
      if (s.recorder.state !== 'inactive') s.recorder.stop();
      s.stream.getTracks().forEach(t => t.stop());
      try {
        await s.stopped;
        const blob = new Blob(s.chunks, { type: s.recorder.mimeType });
        const decoded = await s.context.decodeAudioData(await blob.arrayBuffer());
        if (s.cancelled) throw new Error('Dictée annulée.');
        const count = Math.min(Math.floor(decoded.duration * 16000), 60 * 16000);
        if (count < 1600) throw new Error('Enregistrement trop court.');
        const wav = new ArrayBuffer(44 + count * 2), view = new DataView(wav);
        const str = (i, text) => { for (let k = 0; k < text.length; k++) view.setUint8(i+k, text.charCodeAt(k)); };
        str(0, 'RIFF'); view.setUint32(4, 36 + count * 2, true); str(8,'WAVE'); str(12,'fmt '); view.setUint32(16,16,true); view.setUint16(20,1,true); view.setUint16(22,1,true); view.setUint32(24,16000,true); view.setUint32(28,32000,true); view.setUint16(32,2,true); view.setUint16(34,16,true); str(36,'data'); view.setUint32(40,count*2,true);
        const channels = Array.from({length: decoded.numberOfChannels}, (_, c) => decoded.getChannelData(c));
        for (let i = 0; i < count; i++) {
          const index = i * decoded.sampleRate / 16000, begin = Math.floor(index), end = Math.max(begin + 1, Math.floor((i+1)*decoded.sampleRate/16000));
          let sample = 0, n = 0;
          for (const channel of channels) for (let j = begin; j < Math.min(end, channel.length); j++) { sample += channel[j]; n++; }
          sample = Math.max(-1, Math.min(1, sample / Math.max(1,n)));
          view.setInt16(44+i*2, Math.round(sample * (sample < 0 ? 32768 : 32767)), true);
        }
        let binary = ''; const bytes = new Uint8Array(wav);
        for (let i = 0; i < bytes.length; i += 8192) binary += String.fromCharCode(...bytes.subarray(i, i+8192));
        return btoa(binary);
      } finally { release(s); if (session === s) session = null; }
    },
    cancel() { const s = session; if (!s) return; session = null; s.cancelled = true; clearTimeout(s.timer); if (s.recorder?.state !== 'inactive') { try { s.recorder?.stop(); } catch (_) {} } release(s); },
  };
  window.addEventListener('pagehide', () => window.lectorVoice.cancel());
})();
