#!/usr/bin/env perl
# Regras de transformação baseadas em revenuecat-api.patch

# 1. Adiciona Codable à classe SubscriptionPeriod
s/^(public final class SubscriptionPeriod: NSObject)$/$1,Codable/m;

# 2. Adiciona Codable ao enum Unit
s/^(\s+public enum Unit: Int)$/$1, Codable/m;

# 3. Remove as extensões Codable do final do arquivo
s/\n\n\/\/ MARK: - Encodable\n\nextension SubscriptionPeriod\.Unit: Codable \{ \}\nextension SubscriptionPeriod: Codable \{ \}\n?$//s;
