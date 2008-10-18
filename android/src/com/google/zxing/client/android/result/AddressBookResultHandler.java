/*
 * Copyright (C) 2008 ZXing authors
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

package com.google.zxing.client.android.result;

import android.app.Activity;
import android.telephony.PhoneNumberUtils;
import android.text.SpannableString;
import android.text.style.StyleSpan;
import com.google.zxing.client.android.R;
import com.google.zxing.client.result.AddressBookParsedResult;
import com.google.zxing.client.result.ParsedResult;

import java.text.DateFormat;
import java.text.ParsePosition;
import java.text.SimpleDateFormat;
import java.util.Date;

public class AddressBookResultHandler extends ResultHandler {

  private boolean mFields[];
  private int mButtonCount;

  // This takes all the work out of figuring out which buttons/actions should be in which
  // positions, based on which fields are present in this barcode.
  private int mapIndexToAction(int index) {
    if (index < mButtonCount) {
      int count = -1;
      for (int x = 0; x < MAX_BUTTON_COUNT; x++) {
        if (mFields[x]) count++;
        if (count == index) return x;
      }
    }
    return -1;
  }

  public AddressBookResultHandler(Activity activity, ParsedResult result) {
    super(activity, result);
    AddressBookParsedResult addressResult = (AddressBookParsedResult) result;
    String address = addressResult.getAddress();
    boolean hasAddress = address != null && address.length() > 0;
    String[] phoneNumbers = addressResult.getPhoneNumbers();
    boolean hasPhoneNumber = phoneNumbers != null && phoneNumbers.length > 0;
    String[] emails = addressResult.getEmails();
    boolean hasEmailAddress = emails != null && emails.length > 0;

    mFields = new boolean[MAX_BUTTON_COUNT];
    mFields[0] = true; // Add contact is always available
    mFields[1] = hasAddress;
    mFields[2] = hasPhoneNumber;
    mFields[3] = hasEmailAddress;

    mButtonCount = 0;
    for (int x = 0; x < MAX_BUTTON_COUNT; x++) {
      if (mFields[x]) mButtonCount++;
    }
  }

  public int getButtonCount() {
    return mButtonCount;
  }

  public int getButtonText(int index) {
    int action = mapIndexToAction(index);
    switch (action) {
      case 0:
        return R.string.button_add_contact;
      case 1:
        return R.string.button_show_map;
      case 2:
        return R.string.button_dial;
      case 3:
        return R.string.button_email;
      default:
        throw new ArrayIndexOutOfBoundsException();
    }
  }

  public void handleButtonPress(int index) {
    AddressBookParsedResult addressResult = (AddressBookParsedResult) mResult;
    int action = mapIndexToAction(index);
    switch (action) {
      case 0:
        addContact(addressResult.getNames(), addressResult.getPhoneNumbers(),
            addressResult.getEmails(), addressResult.getNote(),
            addressResult.getAddress(), addressResult.getOrg(),
            addressResult.getTitle());
        break;
      case 1:
        searchMap(addressResult.getAddress());
        break;
      case 2:
        dialPhone(addressResult.getPhoneNumbers()[0]);
        break;
      case 3:
        sendEmail(addressResult.getEmails()[0], null, null);
        break;
      default:
        break;
    }
  }

  // Overriden so we can hyphenate phone numbers, format birthdays, and bold the name.
  @Override
  public CharSequence getDisplayContents() {
    AddressBookParsedResult result = (AddressBookParsedResult) mResult;
    StringBuffer contents = new StringBuffer();
    ParsedResult.maybeAppend(result.getNames(), contents);
    int namesLength = contents.length();

    ParsedResult.maybeAppend(result.getTitle(), contents);
    ParsedResult.maybeAppend(result.getOrg(), contents);
    ParsedResult.maybeAppend(result.getAddress(), contents);
    String[] numbers = result.getPhoneNumbers();
    if (numbers != null) {
      for (String number : numbers) {
        ParsedResult.maybeAppend(PhoneNumberUtils.formatNumber(number), contents);
      }
    }
    ParsedResult.maybeAppend(result.getEmails(), contents);
    ParsedResult.maybeAppend(result.getURL(), contents);

    String birthday = result.getBirthday();
    if (birthday != null && birthday.length() > 0) {
      SimpleDateFormat format = new SimpleDateFormat("yyyyMMdd");
      Date date = format.parse(birthday, new ParsePosition(0));
      ParsedResult.maybeAppend(DateFormat.getDateInstance().format(date.getTime()), contents);
    }
    ParsedResult.maybeAppend(result.getNote(), contents);

    if (namesLength > 0) {
      // Bold the full name to make it stand out a bit.
      SpannableString styled = new SpannableString(contents.toString());
      styled.setSpan(new StyleSpan(android.graphics.Typeface.BOLD), 0, namesLength, 0);
      return styled;
    } else {
      return contents.toString();
    }
  }

  public int getDisplayTitle() {
    return R.string.result_address_book;
  }

}
