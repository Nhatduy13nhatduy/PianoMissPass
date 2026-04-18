#include <jni.h>
#include <android/log.h>
#include <oboe/Oboe.h>
#include <memory>
#include <mutex>

#define TSF_IMPLEMENTATION
#include "tsf.h"

#define LOG_TAG "FlutterMIDI16KB"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

constexpr int SAMPLE_RATE = 48000;

class MIDIPlayer : public oboe::AudioStreamDataCallback {
private:
    std::shared_ptr<oboe::AudioStream> stream;
    tsf* soundfont = nullptr;
    std::mutex mutex;
    bool initialized = false;
    
public:
    bool initialize() {
        if (initialized) return true;
        
        oboe::AudioStreamBuilder builder;
        oboe::Result result = builder
            .setDirection(oboe::Direction::Output)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
            ->setSharingMode(oboe::SharingMode::Exclusive)
            ->setFormat(oboe::AudioFormat::Float)
            ->setChannelCount(oboe::ChannelCount::Stereo)
            ->setSampleRate(SAMPLE_RATE)
            ->setDataCallback(this)
            ->openStream(stream);
        
        if (result != oboe::Result::OK) {
            LOGE("Failed to create stream: %s", oboe::convertToText(result));
            return false;
        }
        
        result = stream->requestStart();
        if (result != oboe::Result::OK) {
            LOGE("Failed to start stream: %s", oboe::convertToText(result));
            return false;
        }
        
        initialized = true;
        LOGD("MIDI Player initialized");
        return true;
    }
    
    bool loadSoundfont(const char* path) {
        std::lock_guard<std::mutex> lock(mutex);
        
        if (soundfont) {
            tsf_close(soundfont);
        }
        
        soundfont = tsf_load_filename(path);
        if (!soundfont) {
            LOGE("Failed to load soundfont: %s", path);
            return false;
        }
        
        tsf_set_output(soundfont, TSF_STEREO_INTERLEAVED, SAMPLE_RATE, 0.0f);
        LOGD("Soundfont loaded: %s", path);
        return true;
    }
    
    void playNote(int ch, int key, int vel) {
        std::lock_guard<std::mutex> lock(mutex);
        if (soundfont) tsf_note_on(soundfont, ch, key, vel / 127.0f);
    }
    
    void stopNote(int ch, int key) {
        std::lock_guard<std::mutex> lock(mutex);
        if (soundfont) tsf_note_off(soundfont, ch, key);
    }
    
    void stopAllNotes() {
        std::lock_guard<std::mutex> lock(mutex);
        if (soundfont) {
            for (int ch = 0; ch < 16; ch++) {
                tsf_channel_note_off_all(soundfont, ch);
            }
        }
    }
    
    void changeProgram(int ch, int prog) {
        std::lock_guard<std::mutex> lock(mutex);
        if (soundfont) tsf_channel_set_presetnumber(soundfont, ch, prog, 0);
    }
    
    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream *audioStream,
        void *audioData,
        int32_t numFrames) override {
        
        float *output = static_cast<float*>(audioData);
        std::lock_guard<std::mutex> lock(mutex);
        
        if (!soundfont) {
            memset(output, 0, numFrames * 2 * sizeof(float));
        } else {
            tsf_render_float(soundfont, output, numFrames, 0);
        }
        
        return oboe::DataCallbackResult::Continue;
    }
    
    void cleanup() {
        if (stream) {
            stream->stop();
            stream->close();
            stream.reset();
        }
        if (soundfont) {
            tsf_close(soundfont);
            soundfont = nullptr;
        }
        initialized = false;
    }
    
    ~MIDIPlayer() { cleanup(); }
};

static MIDIPlayer* player = nullptr;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativeInitialize(
    JNIEnv* env, jobject obj) {
    if (!player) player = new MIDIPlayer();
    return player->initialize();
}

JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativeLoadSoundfont(
    JNIEnv* env, jobject obj, jstring path) {
    if (!player) return false;
    const char* p = env->GetStringUTFChars(path, nullptr);
    bool result = player->loadSoundfont(p);
    env->ReleaseStringUTFChars(path, p);
    return result;
}

JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativeUnloadSoundfont(
    JNIEnv* env, jobject obj) {
    return true;
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativePlayNote(
    JNIEnv* env, jobject obj, jint ch, jint key, jint vel) {
    if (player) player->playNote(ch, key, vel);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativeStopNote(
    JNIEnv* env, jobject obj, jint ch, jint key) {
    if (player) player->stopNote(ch, key);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativeStopAllNotes(
    JNIEnv* env, jobject obj) {
    if (player) player->stopAllNotes();
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativeChangeProgram(
    JNIEnv* env, jobject obj, jint ch, jint prog) {
    if (player) player->changeProgram(ch, prog);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1midi_116kb_FlutterMidi16kbPlugin_nativeDispose(
    JNIEnv* env, jobject obj) {
    if (player) {
        player->cleanup();
        delete player;
        player = nullptr;
    }
}

}
