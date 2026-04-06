/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.util.array;

import std.algorithm;
import std.array;

/**
 * Removes the specified element from the array (once).
 *
 * Params:
 *  array   = The array to remove the item from.
 *  element = The item to look for and remove.
 *
 * Adapted from grestful, modified to explicitly check index
 */
void remove(T)(ref T[] array, T element) {
    auto index = array.countUntil(element);
    while (index >= 0) {
        array = std.algorithm.remove(array, index);
        index = array.countUntil(element);
    }
}

unittest {
    string[] test = ["test1", "test2", "test3"];

    remove(test, "test1");
    assert(test == ["test2", "test3"]);
    remove(test, "test4");
    assert(test == ["test2", "test3"]);
}

/// Test: remove all duplicates of an element
unittest {
    // The remove function uses a while loop, so it removes ALL
    // occurrences of the element, not just the first one.
    string[] test = ["a", "b", "a", "c", "a"];
    remove(test, "a");
    assert(test == ["b", "c"]);
}

/// Test: remove from empty array
unittest {
    string[] test;
    remove(test, "anything");
    assert(test.length == 0);
}

/// Test: remove last element leaves empty array
unittest {
    string[] test = ["only"];
    remove(test, "only");
    assert(test.length == 0);
}

/// Test: remove with integer type
unittest {
    // D lesson — template functions work with any type.
    // remove(T) is defined as a template, so it works with
    // int[], string[], or any T that supports == comparison.
    int[] nums = [1, 2, 3, 2, 4];
    remove(nums, 2);
    assert(nums == [1, 3, 4]);
}
