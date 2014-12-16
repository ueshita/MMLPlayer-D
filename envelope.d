module mml.envelope;

import std.math;

class Envelope
{
	float sustainLevel = 0.5f;

	int sampleRate;
	int sampleCount;
	int attack;
	int decay;
	int sustain;
	int release;

	enum State {
		Attack, Decay, Sustain, Release, Completed,
	}

	State state;
	bool autoKeyOff = true;

public:
	this(int sampleRate) {
		this.sampleRate = sampleRate;
	}
	void setADSR(int attack, int decay, int sustain, int release) {
		this.attack  = this.sampleRate * attack  / 127;
		this.decay   = this.sampleRate * decay   / 127;
		this.release = this.sampleRate * release / 127;
		this.sustainLevel = cast(float)sustain   / 127;
	}
	void setLength(int length) {
		this.sustain = length - this.release;
		if (this.autoKeyOff) {
			this.sustain -= this.attack + this.decay;
		}
		if (this.sustain < 0) this.sustain = 0;
	}
	float gen() {
		this.sampleCount++;
		final switch (this.state) {
		case State.Attack:
			if (this.sampleCount < this.attack) {
				return 1.0f * this.sampleCount / this.attack;
			} else {
				this.sampleCount = 0;
				this.state = State.Decay;
			}
		case State.Decay:
			if (this.sampleCount < this.decay) {
				return 1.0f - (1.0f - this.sustainLevel) * this.sampleCount / this.decay;
			} else {
				this.sampleCount = 0;
				this.state = State.Sustain;
			}
		case State.Sustain:
			if (this.autoKeyOff && this.sampleCount >= this.sustain) {
				this.sampleCount = 0;
				this.state = State.Release;
			} else {
				return this.sustainLevel;
			}
		case State.Release:
			if (this.sampleCount < this.release) {
				return this.sustainLevel - this.sustainLevel * this.sampleCount / this.release;
			} else {
				this.sampleCount = 0;
				this.state = State.Completed;
			}
			break;
		case State.Completed:
			break;
		}
		return 0;
	}
	void keyOn() {
		this.state = State.Attack;
		this.sampleCount = 0;
	}
	void keyOff() {
		this.state = State.Release;
		this.sampleCount = 0;
	}
}
