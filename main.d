module mml.main;

import core.thread;
import std.stdio, std.conv, std.file;
import deimos.portaudio;
import mml.player;

void main(string[] args)
{
	if (args.length > 2) {
		return;
	}

	string mmlText = readText(args[1]);

    PaError err;
    try {
        err = Pa_Initialize();
        if (err != paNoError) {
            throw new Exception(to!string(Pa_GetErrorText(err)));
        }
		
		const int sampleRate = 44100;
		auto player = new MMLPlayer(sampleRate);

        PaStream* stream;
		player.setMML(mmlText);
		player.play();

        err = Pa_OpenDefaultStream(&stream,
            0, 2, paFloat32, sampleRate,
            paFramesPerBufferUnspecified,
            &audioCallback, &player);
        if (err != paNoError) {
            throw new Exception(to!string(Pa_GetErrorText(err)));
        }

        Pa_StartStream(stream);

		while (player.playing) {
			Pa_Sleep(10);
		}

        Pa_StopStream(stream);
        Pa_CloseStream(stream);
        Pa_Terminate();
    } catch (Exception e) {
        stderr.writefln("error %s", e);
    }
}

extern(C) nothrow
int audioCallback(const(void)* inputBuffer, 
		  void* outputBuffer,
		  size_t framesPerBuffer,
		  const(PaStreamCallbackTimeInfo)* timeInfo,
		  PaStreamCallbackFlags statusFlags,
		  void *userData)
{
	try {
		if (Thread.getThis() is null) {
			thread_attachThis();
		}

		auto player = cast(MMLPlayer*)userData;
		auto pout = cast(float*)outputBuffer;

		foreach(i; 0 .. framesPerBuffer) {
			FrameData frame = player.synth();
			*pout++ = frame.data[0];
			*pout++ = frame.data[1];
		}
	} catch (Exception e) {
	} catch (Error e) {
	}
	return 0;
}
