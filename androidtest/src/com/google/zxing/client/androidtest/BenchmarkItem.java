/*
 * Copyright (C) 2008 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.zxing.client.androidtest;

import com.google.zxing.BarcodeFormat;

public final class BenchmarkItem {

  private final String mPath;
  private int[] mTimes;
  private int mPosition;
  private boolean mDecoded;
  private BarcodeFormat mFormat;

  public BenchmarkItem(String path, int runs) {
    mPath = path;
    assert(runs > 0);
    mTimes = new int[runs];
    mPosition = 0;
    mDecoded = false;
    mFormat = null;
  }

  public final void addResult(int microseconds) {
    mTimes[mPosition] = microseconds;
    mPosition++;
  }

  public final void setDecoded(boolean decoded) {
    mDecoded = decoded;
  }

  public final void setFormat(BarcodeFormat format) {
    mFormat = format;
  }

  @Override
  public final String toString() {
    StringBuffer result = new StringBuffer();
    result.append(mDecoded ? ("DECODED " + mFormat.toString() + ": ") : "FAILED: ");
    result.append(mPath);
    result.append(" (");
    result.append(getAverageTime());
    result.append(" us average)");
//    int size = mTimes.length;
//    for (int x = 0; x < size; x++) {
//      result.append(mTimes[x]);
//      result.append(" ");
//    }
    return result.toString();
  }

  /**
   * Calculates the average time but throws out the maximum as an outlier first.
   *
   * @return The average decoding time in microseconds.
   */
  private int getAverageTime() {
    int size = mTimes.length;
    int total = 0;
    int max = mTimes[0];
    for (int x = 0; x < size; x++) {
      int time = mTimes[x];
      total += time;
      if (time > max) {
        max = time;
      }
    }
    total -= max;
    size--;
    if (size > 0) {
      return total / size;
    } else {
      return 0;
    }
  }

}
