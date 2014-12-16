module mml.player;

import std.stdio;
import mml.track, mml.utility;

struct FrameData
{
	float[2] data = [0, 0];
}

class MMLPlayer
{
	string mml;
	bool playing = false;
	int sampleRate = 0;
	float volume = 0.8f;
	MMLSequencer sequencer;
	MMLTrack[] tracks;
	
	this(int sampleRate) {
		this.sampleRate = sampleRate;
		this.sequencer = new MMLSequencer(sampleRate);
	}
	
	void setMML(string mml) {
		this.mml = mml;
		auto trackCommands = parseMML(mml, this.sequencer.option);

		this.tracks.length = trackCommands.length;
		for (int i = 0; i < trackCommands.length; i++) {
			this.tracks[i] = new MMLTrack(sequencer, trackCommands[i]);
		}
	}
	void reset() {
		foreach (track; this.tracks) {
			track.reset();
		}
	}
	void play() {
		if (this.tracks == null) {
			return;
		}
		this.playing = true;
	}
	void stop() {
		this.playing = false;
	}
	FrameData synth() {
		FrameData frame;

		if (!this.playing) {
			return frame;
		}

		bool completed = true;
		foreach (track; this.tracks) {
			completed &= track.completed;
		}
		if (completed) {
			this.playing = false;
			return frame;
		}
		
		foreach (track; this.tracks) {
			frame.data[] += track.synth().data[];
		}
		frame.data[] *= this.volume;
		return frame;
	}	
}
