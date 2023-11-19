# Emerald Timestamp

## Overview

This directory contains code for the iOS Timestamp app (universal for both iPhone and iPad).

The app allows the user to create events with NTP-corrected time and an associated description for each event.

## Dependencies

Please see the note in the `docs` repository about dependent libraries -- the Xcode build process
requires that all of the libraries required by this app be at the same level as the app directory
itself.

One way to set up the dependencies required for Timestamp would be to use [ssh](https://docs.github.com/en/authentication/connecting-to-github-with-ssh):

```shell
mkdir emeraldsequoia
cd emeraldsequoia
git clone git@github.com:EmeraldSequoia/Timestamp.git
git clone git@github.com:EmeraldSequoia/buildscripts.git
git clone git@github.com:EmeraldSequoia/esutil.git
git clone git@github.com:EmeraldSequoia/estime.git
git clone git@github.com:EmeraldSequoia/eslocation.git

```

## Xcode project

The Xcode project file for the app is at the top level of this repository, at `timestamp.xcodeproj`.
It has only one target, so to build and run the app, just choose a destination (a simulator or,
if you have set up your Xcode development profiles, a device) and select Product -> Run.

## Versioning

The current app version as displayed to the user is inside `Help/Help.html` as EMERALD_VERSION_STRING.
You should change this to the current version before submitting a version to the App Store.

## Links to Emerald Sequoia website

That same help file has links to the Emerald Sequoia website for
things like Copyright notices and release notes. These should be
changed to point to GitHub somewhere, as the Emerald Sequoia website
is going away.
