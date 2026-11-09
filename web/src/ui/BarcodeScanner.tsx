import { useEffect, useRef, useState } from "react";
import { normalizeBarcode } from "../engines/barcode";
import { Button, Icon, Sheet } from "./kit";

type ScanStatus = "starting" | "scanning" | "insecure" | "denied" | "nocamera" | "error";

interface DetectedBarcode {
  rawValue: string;
}
interface BarcodeDetectorLike {
  detect(source: CanvasImageSource): Promise<DetectedBarcode[]>;
}
interface BarcodeDetectorCtor {
  new (opts: { formats: string[] }): BarcodeDetectorLike;
  getSupportedFormats(): Promise<string[]>;
}

const NATIVE_FORMATS = ["ean_13", "ean_8", "upc_a"];

const STATUS_TEXT: Record<Exclude<ScanStatus, "scanning">, string> = {
  starting: "Starting camera…",
  insecure: "The camera needs a secure connection (HTTPS or localhost). Type the barcode number below instead.",
  denied: "Camera permission was denied. Allow camera access for this site in Chrome's settings, or type the number below.",
  nocamera: "No camera found on this device. Type the barcode number below.",
  error: "Couldn't start the camera. Type the barcode number below.",
};

/**
 * Live camera barcode scanner. Uses the browser's native BarcodeDetector (Android Chrome) and falls back
 * to the ZXing decoder (loaded on demand) elsewhere. Only codes with a valid GS1 check digit are accepted,
 * which filters out misreads.
 */
export function BarcodeScanner({ onDetected, onClose }: { onDetected: (code: string) => void; onClose: () => void }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [status, setStatus] = useState<ScanStatus>("starting");
  const [manual, setManual] = useState("");
  const [manualError, setManualError] = useState<string>();
  const done = useRef(false);
  const onDetectedRef = useRef(onDetected);
  onDetectedRef.current = onDetected;

  useEffect(() => {
    let stream: MediaStream | undefined;
    let stopped = false;
    let raf = 0;
    let zxing: { stop: () => void } | undefined;

    const finish = (raw: string) => {
      if (done.current || stopped) return;
      const code = normalizeBarcode(raw);
      if (!code) return;
      done.current = true;
      try {
        navigator.vibrate?.(60);
      } catch {
        /* ignore */
      }
      onDetectedRef.current(code);
    };

    (async () => {
      if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
        setStatus("insecure");
        return;
      }
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: "environment" }, width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: false,
        });
      } catch (e) {
        const name = (e as DOMException).name;
        setStatus(name === "NotAllowedError" ? "denied" : name === "NotFoundError" ? "nocamera" : "error");
        return;
      }
      if (stopped) {
        stream.getTracks().forEach((t) => t.stop());
        return;
      }
      const video = videoRef.current!;
      video.srcObject = stream;
      await video.play().catch(() => {});
      setStatus("scanning");

      const Detector = (window as unknown as { BarcodeDetector?: BarcodeDetectorCtor }).BarcodeDetector;
      let formats: string[] = [];
      if (Detector) {
        try {
          formats = (await Detector.getSupportedFormats()).filter((f) => NATIVE_FORMATS.includes(f));
        } catch {
          formats = [];
        }
      }

      if (Detector && formats.length) {
        const detector = new Detector({ formats });
        let busy = false;
        const tick = async () => {
          if (stopped || done.current) return;
          if (!busy && video.readyState >= 2) {
            busy = true;
            try {
              for (const c of await detector.detect(video)) finish(c.rawValue);
            } catch {
              /* frame not ready */
            }
            busy = false;
          }
          raf = requestAnimationFrame(tick);
        };
        raf = requestAnimationFrame(tick);
      } else {
        const [{ BrowserMultiFormatReader }, { BarcodeFormat, DecodeHintType }] = await Promise.all([
          import("@zxing/browser"),
          import("@zxing/library"),
        ]);
        if (stopped) return;
        const hints = new Map();
        hints.set(DecodeHintType.POSSIBLE_FORMATS, [BarcodeFormat.EAN_13, BarcodeFormat.EAN_8, BarcodeFormat.UPC_A]);
        const reader = new BrowserMultiFormatReader(hints);
        zxing = await reader.decodeFromVideoElement(video, (result) => {
          if (result) finish(result.getText());
        });
        if (stopped) zxing.stop();
      }
    })();

    return () => {
      stopped = true;
      cancelAnimationFrame(raf);
      zxing?.stop();
      stream?.getTracks().forEach((t) => t.stop());
    };
  }, []);

  function submitManual() {
    const code = normalizeBarcode(manual);
    if (!code) {
      setManualError("That doesn't look like a valid 8, 12, 13 or 14-digit barcode.");
      return;
    }
    done.current = true;
    onDetected(code);
  }

  return (
    <Sheet title="Scan Barcode" full onClose={onClose}>
      <div
        style={{
          position: "relative",
          borderRadius: "var(--r-lg)",
          overflow: "hidden",
          background: "#000",
          aspectRatio: "3 / 4",
          maxHeight: "60dvh",
          width: "100%",
        }}
      >
        <video
          ref={videoRef}
          playsInline
          muted
          style={{ width: "100%", height: "100%", objectFit: "cover", display: status === "scanning" ? "block" : "none" }}
        />
        {status === "scanning" ? (
          <div
            aria-hidden="true"
            style={{
              position: "absolute",
              left: "10%",
              right: "10%",
              top: "38%",
              height: "24%",
              border: "3px solid rgba(255,255,255,0.9)",
              borderRadius: 14,
              boxShadow: "0 0 0 9999px rgba(0,0,0,0.35)",
            }}
          />
        ) : (
          <div className="stack center" style={{ position: "absolute", inset: 0, justifyContent: "center", padding: 24, color: "#fff" }}>
            <Icon name="barcode" size={40} />
            <p style={{ fontSize: 14 }}>{STATUS_TEXT[status]}</p>
          </div>
        )}
      </div>
      {status === "scanning" && <p className="caption center">Line the barcode up inside the frame. It scans automatically.</p>}

      <form
        className="stack-sm"
        onSubmit={(e) => {
          e.preventDefault();
          submitManual();
        }}
      >
        <label className="field">
          <span>Or type the barcode number</span>
          <input
            className="input"
            inputMode="numeric"
            enterKeyHint="search"
            placeholder="e.g. 3017620422003"
            value={manual}
            onChange={(e) => {
              setManual(e.target.value.replace(/[^\d]/g, ""));
              setManualError(undefined);
            }}
          />
        </label>
        {manualError && <span className="caption danger">{manualError}</span>}
        <Button type="submit" variant="secondary" disabled={manual.length < 8}>
          Look Up
        </Button>
      </form>
    </Sheet>
  );
}
