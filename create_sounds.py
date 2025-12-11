import wave
import math

def create_beep(filename, frequency, duration_ms, sample_rate=44100):
    """Create a simple beep sound file"""
    num_samples = int(sample_rate * duration_ms / 1000)
    frames = []
    
    for i in range(num_samples):
        sample = int(32767.0 * 0.3 * math.sin(2.0 * math.pi * frequency * i / sample_rate))
        frames.append(sample)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        for frame in frames:
            wav_file.writeframes(frame.to_bytes(2, 'little', signed=True))

# Create correct sound (high-pitched beep)
create_beep('assets/sounds/correct.wav', 800, 100)
print('Created correct.wav')

# Create incorrect sound (low-pitched beep)
create_beep('assets/sounds/incorrect.wav', 400, 100)
print('Created incorrect.wav')
