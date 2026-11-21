#import <CoreAudio/CoreAudio.h>

// Keep the original Objective-C block for removal. Swift bridges closures anew on each call.
static inline OSStatus PairPodsObserveAudioProperty(
    AudioObjectID object,
    AudioObjectPropertyAddress address,
    AudioObjectPropertyListenerBlock _Nonnull listener,
    void (^ _Nullable * _Nonnull removeListener)(void)
) {
    dispatch_queue_t queue = dispatch_get_main_queue();
    OSStatus status = AudioObjectAddPropertyListenerBlock(object, &address, queue, listener);
    if (status == noErr) {
        *removeListener = ^{
            AudioObjectRemovePropertyListenerBlock(object, &address, queue, listener);
        };
    }
    return status;
}
