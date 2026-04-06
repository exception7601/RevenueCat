#!/usr/bin/env perl

s/^(public final class SubscriptionPeriod: NSObject)$/$1,Codable/m;

s/^(\s+public enum Unit: Int)$/$1, Codable/m;

s/^extension SubscriptionPeriod\.Unit: Codable \{ \}$//m;

s/^extension SubscriptionPeriod: Codable \{ \}$//m;
