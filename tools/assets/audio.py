"""Original interface cues, synthesized locally; no external audio license."""
from pathlib import Path
import math, struct, wave
root=Path(__file__).resolve().parents[2]/"client/assets/audio"
root.mkdir(parents=True,exist_ok=True)
rate=22050
for name,duration,notes in [("select",.12,[(240,.26),(720,.08)]),("complete",1.4,[(523,.2),(784,.12),(1046,.06)])]:
 samples=[]
 for i in range(int(rate*duration)):
  t=i/rate
  fade=min(1,t/.01)*max(0,1-t/duration)
  value=sum(amp*math.sin(2*math.pi*hz*t)*math.exp(-t*(20 if name=="select" else 3)) for hz,amp in notes)*fade
  samples.append(struct.pack("<h",int(max(-1,min(1,value))*32767)))
 with wave.open(str(root/(name+".wav")),"wb") as out:
  out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(b"".join(samples))
