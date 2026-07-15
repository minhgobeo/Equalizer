#!/usr/bin/env python3
"""
Quick test runner for adaptive tau + transition gate improvements.
Uses MATLAB Engine to avoid CLI issues on Windows.
"""

import os
import sys

# Try to import MATLAB engine
try:
    import matlab.engine
except ImportError:
    print("MATLAB Engine for Python not installed.")
    print("Please install: pip install matlabengine")
    sys.exit(1)

def main():
    print("=" * 70)
    print("Testing Adaptive Tau + Transition Gate (802.3ck C2M Markov)")
    print("=" * 70)
    print("Quick test: 3 trials, Pstay=[0.97, 0.93]")
    print("New features: use_adaptive_tau=true, tau_calib=1.0, use_transition_gate=true")
    print()

    # Start MATLAB engine
    print("[1/4] Starting MATLAB Engine...")
    try:
        eng = matlab.engine.start_matlab()
        print("✓ MATLAB Engine started")
    except Exception as e:
        print(f"✗ Failed to start MATLAB: {e}")
        return 1

    try:
        # Setup paths
        print("[2/4] Setting up paths...")
        eng.addpath(eng.genpath('core'), nargout=0)
        eng.addpath(eng.genpath('utils'), nargout=0)
        eng.addpath(eng.genpath('experiments'), nargout=0)
        eng.addpath(eng.genpath('channel'), nargout=0)
        eng.addpath(eng.genpath('config'), nargout=0)
        print("✓ Paths configured")

        # Build configs
        print("[3/4] Building configurations...")
        cfg = eng.build_main_config()
        mc = eng.build_mc_config(cfg)
        vars_build = eng.build_variants(cfg)
        base = eng.build_baselines()
        print("✓ Configs built")

        # Run benchmark
        print("[4/4] Running benchmark (3 trials, ~15-20 min)...")
        print("  - Markov slow (Pstay=0.97)")
        print("  - Markov medium (Pstay=0.93)")
        print()

        pkg = eng.run_8023ck_sparam_benchmark(
            cfg, vars_build, base, mc,
            'trials', 3,
            'p_stay', matlab.double([0.970, 0.930]),
            'save_dir', 'test_adaptive_tau_markov_t3',
            nargout=1
        )

        print("\n" + "=" * 70)
        print("RESULTS")
        print("=" * 70)

        # Parse results
        if hasattr(pkg, 'markov') and len(pkg['markov']) > 0:
            markov = pkg['markov']

            # Find Proposed and Chen rows for slow case
            slow_proposed = None
            slow_chen = None

            for row in markov:
                if 'Markov_slow' in str(row['case_id']):
                    if 'Proposed' in str(row['method']):
                        slow_proposed = row
                    elif 'Chen' in str(row['method']):
                        slow_chen = row

            if slow_proposed and slow_chen:
                print("\nSLOW (Pstay=0.97)")
                print("-" * 70)
                proposed_ber = float(slow_proposed['BER'])
                chen_ber = float(slow_chen['BER'])
                state_acc = float(slow_proposed['state_accuracy']) * 100

                print(f"  Proposed BER: {proposed_ber:.6e}")
                print(f"  Chen BER:     {chen_ber:.6e}")
                print(f"  State Accuracy: {state_acc:.1f}%")

                improvement = 100 * (1 - proposed_ber / max(chen_ber, 1e-12))
                print(f"  Improvement vs Chen: {improvement:.1f}%")

                if improvement >= 20:
                    print("  ✓ ACHIEVED +20% TARGET!")
                else:
                    print(f"  → Need: {20 - improvement:.1f}% more")

        print("\n" + "=" * 70)
        print(f"Full results saved to: test_adaptive_tau_markov_t3/")
        print("=" * 70)

        return 0

    except Exception as e:
        print(f"✗ Error during execution: {e}")
        import traceback
        traceback.print_exc()
        return 1

    finally:
        print("\nClosing MATLAB Engine...")
        eng.quit()

if __name__ == '__main__':
    sys.exit(main())
