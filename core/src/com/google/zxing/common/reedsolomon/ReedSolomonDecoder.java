/*
 * Copyright 2007 Google Inc.
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

package com.google.zxing.common.reedsolomon;

/**
 * <p>Implements Reed-Solomon decoding, as the name implies.</p>
 *
 * <p>The algorithm will not be explained here, but the following references were helpful
 * in creating this implementation:</p>
 *
 * <ul>
 * <li>Bruce Maggs.
 * <a href="http://www.cs.cmu.edu/afs/cs.cmu.edu/project/pscico-guyb/realworld/www/rs_decode.ps">
 * "Decoding Reed-Solomon Codes"</a> (see discussion of Forney's Formula)</li>
 * <li>J.I. Hall. <a href="www.mth.msu.edu/~jhall/classes/codenotes/GRS.pdf">
 * "Chapter 5. Generalized Reed-Solomon Codes"</a>
 * (see discussion of Euclidean algorithm)</li>
 * </ul>
 *
 * <p>Much credit is due to William Rucklidge since portions of this code are an indirect
 * port of his C++ Reed-Solomon implementation.</p>
 *
 * @author srowen@google.com (Sean Owen)
 * @author William Rucklidge
 */
public final class ReedSolomonDecoder {

  private final GF256 field;

  public ReedSolomonDecoder(GF256 field) {
    this.field = field;
  }

  /**
   * <p>Decodes given set of received codewords, which include both data and error-correction
   * codewords. Really, this means it uses Reed-Solomon to detect and correct errors, in-place,
   * in the input.</p>
   *
   * @param received data and error-correction codewords
   * @param twoS number of error-correction codewords available
   * @throws ReedSolomonException if decoding fails for any reaosn
   */
  public void decode(int[] received, int twoS) throws ReedSolomonException {
    GF256Poly poly = new GF256Poly(field, received);
    int[] syndromeCoefficients = new int[twoS];
    boolean noError = true;
    for (int i = 0; i < twoS; i++) {
      int eval =  poly.evaluateAt(field.exp(i));
      syndromeCoefficients[syndromeCoefficients.length - 1 - i] = eval;
      if (eval != 0) {
        noError = false;
      }
    }
    if (noError) {
      return;
    }
    GF256Poly syndrome = new GF256Poly(field, syndromeCoefficients);
    GF256Poly[] sigmaOmega =
        runEuclideanAlgorithm(field.buildMonomial(twoS, 1), syndrome, twoS);
    int[] errorLocations = findErrorLocations(sigmaOmega[0]);
    int[] errorMagnitudes = findErrorMagnitudes(sigmaOmega[1], errorLocations);
    for (int i = 0; i < errorLocations.length; i++) {
      int position = received.length - 1 - field.log(errorLocations[i]);
      received[position] = GF256.addOrSubtract(received[position], errorMagnitudes[i]);
    }
  }

  private GF256Poly[] runEuclideanAlgorithm(GF256Poly a, GF256Poly b, int R)
      throws ReedSolomonException {
    // Assume a's degree is >= b's
    if (a.getDegree() < b.getDegree()) {
      GF256Poly temp = a;
      a = b;
      b = temp;
    }

    GF256Poly rLast = a;
    GF256Poly r = b;
    GF256Poly sLast = field.getOne();
    GF256Poly s = field.getZero();
    GF256Poly tLast = field.getZero();
    GF256Poly t = field.getOne();

    // Run Euclidean algorithm until r's degree is less than R/2
    while (r.getDegree() >= R / 2) {
      GF256Poly rLastLast = rLast;
      GF256Poly sLastLast = sLast;
      GF256Poly tLastLast = tLast;
      rLast = r;
      sLast = s;
      tLast = t;

      // Divide rLastLast by rLast, with quotient in q and remainder in r
      if (rLast.isZero()) {
        // Oops, Euclidean algorithm already terminated?
        throw new ReedSolomonException("r_{i-1} was zero");
      }
      r = rLastLast;
      GF256Poly q = field.getZero();
      int denominatorLeadingTerm = rLast.getCoefficient(rLast.getDegree());
      int dltInverse = field.inverse(denominatorLeadingTerm);
      while (r.getDegree() >= rLast.getDegree() && !r.isZero()) {
        int degreeDiff = r.getDegree() - rLast.getDegree();
        int scale = field.multiply(r.getCoefficient(r.getDegree()), dltInverse);
        q = q.addOrSubtract(field.buildMonomial(degreeDiff, scale));
        r = r.addOrSubtract(rLast.multiplyByMonomial(degreeDiff, scale));
      }

      s = q.multiply(sLast).addOrSubtract(sLastLast);
      t = q.multiply(tLast).addOrSubtract(tLastLast);
    }

    int sigmaTildeAtZero = t.getCoefficient(0);
    if (sigmaTildeAtZero == 0) {
      throw new ReedSolomonException("sigmaTilde(0) was zero");
    }

    int inverse = field.inverse(sigmaTildeAtZero);
    GF256Poly sigma = t.multiply(inverse);
    GF256Poly omega = r.multiply(inverse);
    return new GF256Poly[]{sigma, omega};
  }

  private int[] findErrorLocations(GF256Poly errorLocator) throws ReedSolomonException {
    // This is a direct application of Chien's search
    int numErrors = errorLocator.getDegree();
    if (numErrors == 1) { // shortcut
      return new int[] { errorLocator.getCoefficient(1) };
    }
    int[] result = new int[numErrors];
    int e = 0;
    for (int i = 1; i < 256 && e < numErrors; i++) {
      if (errorLocator.evaluateAt(i) == 0) {
        result[e] = field.inverse(i);
        e++;
      }
    }
    if (e != numErrors) {
      throw new ReedSolomonException("Error locator degree does not match number of roots");
    }
    return result;
  }

  private int[] findErrorMagnitudes(GF256Poly errorEvaluator, int[] errorLocations) {
    // This is directly applying Forney's Formula
    int s = errorLocations.length;
    if (s == 1) { // shortcut
      return new int[] { errorEvaluator.getCoefficient(0) };
    }
    int[] result = new int[s];
    for (int i = 0; i < s; i++) {
      int xiInverse = field.inverse(errorLocations[i]);
      int denominator = 1;
      for (int j = 0; j < s; j++) {
        if (i != j) {
          denominator = field.multiply(denominator,
              GF256.addOrSubtract(1, field.multiply(errorLocations[j], xiInverse)));
        }
      }
      result[i] = field.multiply(errorEvaluator.evaluateAt(xiInverse),
          field.inverse(denominator));
    }
    return result;
  }

}
