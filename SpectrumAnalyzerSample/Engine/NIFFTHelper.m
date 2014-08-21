//
//  NIFFTHelper.m
//
//  Created by Nikita Ivaniushchenko on 6/4/14.
//

#import <stdio.h>
#import <Accelerate/Accelerate.h>
#import <MacTypes.h>

#import "NIFFTHelper.h"

const int NIFFTHelperChannelsCount = 2;
static const UInt32 NIFFTHelperInputBufferSize = 16384;
static const UInt32 NIFFTHelperMaxInputSize = 1024; //10 frequencies
static const UInt32 NIFFTHelperMaxBlocksBeforSkipping = 4;

UInt32 NextPowerOfTwo(UInt32 x);

@interface NIFFTHelper()
{
    FFTSetup _fftSetup;
    Float32* _windowBuffer;
    COMPLEX_SPLIT _complexA[2];
    Float32 *_tmpFFTData0[2];
    Float32 *_outFFTData;
    
    UInt32 _numberOfSamples;
}

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation NIFFTHelper

- (id)init
{
    if (self = [self initWithNumberOfSamples:NIFFTHelperInputBufferSize])
    {
        
    }
    
    return self;
}

- (instancetype)initWithNumberOfSamples:(UInt32)numberOfSamples
{
    if (self = [super init])
    {
        _numberOfSamples = numberOfSamples;
        
        UInt32 nOver2 = NIFFTHelperMaxInputSize/2;
        vDSP_Length log2n = Log2Ceil(NIFFTHelperMaxInputSize);
        
        _fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
        _windowBuffer = (Float32*)malloc(sizeof(Float32)*NIFFTHelperMaxInputSize);
        
        memset(_windowBuffer, 0, sizeof(sizeof(Float32)*NIFFTHelperMaxInputSize));
        vDSP_hann_window(_windowBuffer, NIFFTHelperMaxInputSize, vDSP_HANN_NORM);

        for (int i = 0; i < NIFFTHelperChannelsCount; i++)
        {
            _complexA[i].realp = (Float32*)malloc(NIFFTHelperMaxInputSize*sizeof(Float32));
            _complexA[i].imagp = (Float32*)malloc(NIFFTHelperMaxInputSize*sizeof(Float32));
            
            _tmpFFTData0[i] = (Float32 *)malloc(NIFFTHelperMaxInputSize*sizeof(Float32));
            
            memset(_tmpFFTData0[i], 0, nOver2*sizeof(Float32));
        }
        
        _outFFTData = (Float32 *)malloc(nOver2*sizeof(Float32));
        memset(_outFFTData, 0, nOver2*sizeof(Float32));
        
        _operationQueue = [NSOperationQueue new];
        _operationQueue.maxConcurrentOperationCount = 1;
    }
    
    return self;
}

- (void)dealloc
{
    [self.operationQueue cancelAllOperations];
    
    vDSP_destroy_fftsetup(_fftSetup);
    
    for (int i = 0; i < NIFFTHelperChannelsCount; i++)
    {
        free(_complexA[i].realp);
        free(_complexA[i].imagp);
        free(_tmpFFTData0[i]);
    }
    
    free(_outFFTData);
}

- (void)cleanupChannelInputs:(Float32 **)channelInputs ofSize:(UInt32)size
{
    for (int channel = 0; channel < size; channel++)
    {
        free(channelInputs[channel]);
    }
    
    free(channelInputs);
}

- (void)performComputation:(AudioBufferList *)bufferListInOut completionHandler:(NIFFTHelperCompletionBlock)completion
{
    AudioBuffer audioBuffer0 = bufferListInOut->mBuffers[0];
    
    UInt32 numSamples = MIN(audioBuffer0.mDataByteSize/sizeof(Float32), _numberOfSamples);
    numSamples = NextPowerOfTwo(numSamples);
    
    if (!completion || !numSamples)
    {
        return;
    }

    if (self.operationQueue.operationCount > 1)
    {
        [self.operationQueue cancelAllOperations];
    }
    
    UInt32 maxChannels = MIN(NIFFTHelperChannelsCount, bufferListInOut->mNumberBuffers);
    Float32** channelInputs = (Float32**)malloc(sizeof(Float32)*maxChannels);
    
    for (int i = 0; i < maxChannels; i++)
    {
        channelInputs[i] = (Float32*)malloc(sizeof(Float32)*numSamples);
    }
    
    for (int i = 0; i < maxChannels; i++)
    {
        AudioBuffer audioBuffer = bufferListInOut->mBuffers[i];
        
        if (!audioBuffer.mData)
        {
            [self cleanupChannelInputs:channelInputs ofSize:maxChannels];
            return;
        }
        
        memcpy(channelInputs[i], audioBuffer.mData, sizeof(Float32) * numSamples);
//        vDSP_vmul((Float32 *)audioBuffer.mData, 1, _windowBuffer, 1, channelInputs[i], 1, numSamples);
    }
    
    [self.operationQueue addOperationWithBlock:^
    {
        UInt32 dataBlocksCount = MIN(numSamples/NIFFTHelperMaxInputSize, NIFFTHelperMaxBlocksBeforSkipping);
        
        for (int i = 0; i < dataBlocksCount; i++)
        {
            UInt32 log2FFTSize = Log2Ceil(NIFFTHelperMaxInputSize);

            UInt32 bins = NIFFTHelperMaxInputSize>>1;

            Float32 one = 1.f;
//            Float32 fGainOffset = -3.2f;
            Float32 fBins = bins;
            
            UInt32 dataOffset = i * NIFFTHelperMaxInputSize;
            
            Float32* currentChannelInputs[maxChannels];
            
            for (int channel = 0; channel < maxChannels; channel++)
            {
                currentChannelInputs[channel] = channelInputs[channel] + dataOffset;
                
                vDSP_vmul(currentChannelInputs[channel], 1, _windowBuffer, 1, currentChannelInputs[channel], 1, NIFFTHelperMaxInputSize);
                
                //Convert float array of reals samples to COMPLEX_SPLIT array A
                vDSP_ctoz((COMPLEX*)currentChannelInputs[channel], 2, &(_complexA[channel]), 1, bins);

                //Perform FFT using fftSetup and A
                //Results are returned in A
                vDSP_fft_zrip(_fftSetup, &(_complexA[channel]), 1, log2FFTSize, FFT_FORWARD);

                // compute Z magnitude
                vDSP_zvabs(&(_complexA[channel]), 1, _tmpFFTData0[channel], 1, bins);
                vDSP_vsdiv(_tmpFFTData0[channel], 1, &fBins, _tmpFFTData0[channel], 1, bins);

                //        vDSP_zvmags(&(fftHelperRef->complexA[channel]), 1, fftHelperRef->tmpFFTData0[channel], 1, bins);

                // convert to Db
                vDSP_vdbcon(_tmpFFTData0[channel], 1, &one, _tmpFFTData0[channel], 1, bins, 1);

                // db correction considering window
//                vDSP_vsadd(_tmpFFTData0[channel], 1, &fGainOffset, _tmpFFTData0[channel], 1, bins);
            }

            memcpy(_outFFTData, _tmpFFTData0[0], sizeof(Float32) * bins);

            // stereo analysis ; for this demo, we only support up to 2 channels
            for (int channel = 1; channel < maxChannels; channel++)
            {
                vDSP_vadd(_outFFTData, 1, _tmpFFTData0[channel], 1, _tmpFFTData0[0], 1, bins);
            }
            
            Float32 div = maxChannels;
            vDSP_vsdiv(_outFFTData, 1, &div, _outFFTData, 1, bins);
            
        //    NSMutableString *string = [NSMutableString new];
            
            NSMutableArray *spectrumData = [NSMutableArray new];
            
            for (UInt32 spectrum = 0; spectrum < log2FFTSize; spectrum++)
            {
                Float32 f = _outFFTData[spectrum];
                
                [spectrumData addObject:@(f)];
                
        //        [string appendFormat:@"%8.4f ", f];
            }
            
        //    NSLog(@"%@", string);
            
            completion(spectrumData);
        }
        
        [self cleanupChannelInputs:channelInputs ofSize:maxChannels];
    }];
}
@end

UInt32 CountLeadingZeroes(UInt32 arg)
{
    // GNUC / LLVM has a builtin
#if defined(__GNUC__)
    // on llvm and clang the result is defined for 0
#if (TARGET_CPU_X86 || TARGET_CPU_X86_64) && !defined(__llvm__)
    if (arg == 0) return 32;
#endif	// TARGET_CPU_X86 || TARGET_CPU_X86_64
    return __builtin_clz(arg);
#elif TARGET_OS_WIN32
    UInt32 tmp;
    __asm{
        bsr eax, arg
        mov ecx, 63
        cmovz eax, ecx
        xor eax, 31
        mov tmp, eax	// this moves the result in tmp to return.
    }
    return tmp;
#else
#error "Unsupported architecture"
#endif	// defined(__GNUC__)
}

// base 2 log of next power of two greater or equal to x
UInt32 Log2Ceil(UInt32 x)
{
    return 32 - CountLeadingZeroes(x - 1);
}

// next power of two greater or equal to x
UInt32 NextPowerOfTwo(UInt32 x)
{
    return 1 << Log2Ceil(x);
}
