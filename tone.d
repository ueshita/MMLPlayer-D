module mml.tone;

import std.math, std.random;

class ToneGen
{
protected:
	static const float referenceFrequency = 220;
	int sampleRate = 0;

	float v_frequency = 0;
	float v_scale = 0;
	float v_dutyRatio = 0.5;

	float phaseShift = 0;
	float phase = 0;

public:
	this(int sampleRate) {
		this.sampleRate = sampleRate;
	}
	@property {
		float scale(float value) {
			this.v_scale = value;
			this.v_frequency = this.referenceFrequency * pow(2, value / 12);
			this.phaseShift = this.v_frequency / this.sampleRate;
			return this.v_scale;
		}
		float scale() {
			return this.v_frequency;
		}
	}

	@property {
		float frequency(float value) {
			this.v_frequency = value;
			this.v_scale = 1200 * log2(value / this.referenceFrequency);
			this.phaseShift = this.v_frequency / this.sampleRate;
			return this.v_frequency;
		}
		float frequency() {
			return this.v_frequency;
		}
	}

	@property {
		float dutyRatio(float value) {
			this.v_dutyRatio = value;
			return this.v_dutyRatio;
		}
		float dutyRatio() {
			return this.v_dutyRatio;
		}
	}
	float gen() {
		return 0;
	}
	void reset() {
		this.phase = 0;
	}
}

class SawtoothGen : ToneGen
{
	this(int sampleRate) {
		super(sampleRate);
	}
	override float gen() {
		float result = this.phase;

		this.phase += this.phaseShift;
		if (this.phase >= 1.0f) {
			this.phase -= 2.0f;
		}
		return 0.7f * result;
	}
}

class TriangleGen : ToneGen
{
	this(int sampleRate) {
		super(sampleRate);
	}
	override float gen() {
		float result = this.phase;

		this.phase += this.phaseShift;
		if (this.phase >= 1.0f) {
			this.phase -= 2.0f;
		}
		if (this.phase >= -0.5f && this.phase < 0.5f) {
			return (this.phase + 0.5f) * 2 - 1;
		} else if (this.phase < -0.5f) {
			return 0.0f - (this.phase + 1.0) * 2;
		} else {
			return 1.0f - (this.phase - 0.5) * 2;
		}
	}
}

class SquareGen : ToneGen
{
	this(int sampleRate) {
		super(sampleRate);
	}
	override float gen() {
		float result = this.phase;

		this.phase += this.phaseShift;
		if (this.phase >= 2.0f) {
			this.phase -= 2.0f;
		}
		
		if (this.phase / 2 < this.dutyRatio) {
			return  0.5f;
		} else {
			return -0.5f;
		}
	}
}

class SineGen : ToneGen
{
	this(int sampleRate) {
		super(sampleRate);
	}
	override float gen() {
		float result = this.phase;

		this.phase += this.phaseShift;
		if (this.phase >= 1.0f) {
			this.phase -= 2.0f;
		}
		return sin(this.phase * PI);
	}
}

class WhiteNoiseGen : ToneGen
{
	Xorshift rnd;

	this(int sampleRate) {
		super(sampleRate);
	}
	override float gen() {
		return uniform(0.0f, 1.0f, rnd);
	}
}
