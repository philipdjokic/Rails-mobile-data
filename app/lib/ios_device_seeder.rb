class IosDeviceSeeder

  class << self

    def execute(cmd)
      ActiveRecord::Base.connection.execute(cmd.chomp)
    end

    def seed

      fail "Don't do that" if Rails.env.production?

      ios_device_arches = %(
        INSERT INTO `ios_device_arches` (`id`, `name`, `created_at`, `updated_at`, `deprecated`)
        VALUES
        (1, 'armv6', '2015-12-01 07:40:53', '2015-12-01 07:40:53', 0),
        (2, 'armv7', '2015-12-01 07:41:13', '2015-12-01 07:41:13', 0),
        (3, 'armv7s', '2015-12-01 07:41:15', '2015-12-01 07:41:15', 0),
        (4, 'arm64', '2015-12-01 07:41:38', '2015-12-01 07:41:38', 0);
      )
      execute(ios_device_arches)

      ios_device_families = %(
        INSERT INTO `ios_device_families` (`id`, `name`, `created_at`, `updated_at`, `ios_device_arch_id`, `lookup_name`)
        VALUES
        (1, 'iPhone 6s Plus', '2015-12-01 05:40:08', '2015-12-01 07:42:51', 4, 'iPhone6Plus'),
        (2, 'iPhone 6s', '2015-12-01 05:42:31', '2015-12-01 07:44:00', 4, 'iPhone6'),
        (3, 'iPhone 6 Plus', '2015-12-01 05:44:03', '2015-12-01 07:44:15', 4, 'iPhone6Plus'),
        (4, 'iPhone 6', '2015-12-01 05:45:35', '2015-12-01 07:44:22', 4, 'iPhone6'),
        (5, 'iPhone 5s', '2015-12-01 05:46:41', '2015-12-01 07:45:38', 4, 'iPhone5s'),
        (6, 'iPhone 5c', '2015-12-01 05:48:41', '2015-12-01 07:46:00', 3, 'iPhone5c'),
        (7, 'iPhone 5', '2015-12-01 05:51:57', '2015-12-01 07:46:23', 3, 'iPhone5'),
        (8, 'iPhone 4S', '2015-12-01 05:53:27', '2015-12-01 07:46:38', 2, 'iPhone4S'),
        (9, 'iPod Touch 6th Gen', '2015-12-01 05:55:09', '2015-12-01 07:46:50', 4, 'iPodTouchSixthGen'),
        (10, 'iPod Touch 5th Gen', '2015-12-01 05:55:26', '2015-12-01 07:47:00', 2, 'iPodTouchFifthGen'),
        (11, 'iPod Touch 4th Gen', '2015-12-01 05:56:48', '2015-12-01 07:47:12', 2, NULL);
      )
      execute(ios_device_families)

      ios_device_models = %(
        INSERT INTO `ios_device_models` (`id`, `ios_device_family_id`, `created_at`, `updated_at`, `name`)
        VALUES
        (1, 1, '2015-12-01 05:41:26', '2015-12-01 05:41:26', 'A1699'),
        (2, 1, '2015-12-01 05:41:51', '2015-12-01 05:41:51', 'A1687'),
        (3, 1, '2015-12-01 05:42:17', '2015-12-01 05:42:17', 'A1634'),
        (4, 2, '2015-12-01 05:43:15', '2015-12-01 05:43:15', 'A1700'),
        (5, 2, '2015-12-01 05:43:25', '2015-12-01 05:43:25', 'A1688'),
        (6, 2, '2015-12-01 05:43:48', '2015-12-01 05:43:48', 'A1633'),
        (7, 3, '2015-12-01 05:44:31', '2015-12-01 05:44:31', 'A1593'),
        (8, 3, '2015-12-01 05:44:45', '2015-12-01 05:44:45', 'A1524'),
        (9, 3, '2015-12-01 05:44:56', '2015-12-01 05:44:56', 'A1522'),
        (10, 4, '2015-12-01 05:45:55', '2015-12-01 05:45:55', 'A1589'),
        (11, 4, '2015-12-01 05:46:05', '2015-12-01 05:46:05', 'A1586'),
        (12, 4, '2015-12-01 05:46:14', '2015-12-01 05:46:14', 'A1549'),
        (13, 5, '2015-12-01 05:47:02', '2015-12-01 05:47:02', 'A1518'),
        (14, 5, '2015-12-01 05:47:40', '2015-12-01 05:47:40', 'A1530'),
        (15, 5, '2015-12-01 05:47:51', '2015-12-01 05:47:51', 'A1528'),
        (16, 5, '2015-12-01 05:48:04', '2015-12-01 05:48:04', 'A1457'),
        (17, 5, '2015-12-01 05:48:16', '2015-12-01 05:48:16', 'A1453'),
        (18, 5, '2015-12-01 05:48:25', '2015-12-01 05:48:25', 'A1533'),
        (19, 6, '2015-12-01 05:49:51', '2015-12-01 05:49:51', 'A1516'),
        (20, 6, '2015-12-01 05:50:01', '2015-12-01 05:50:01', 'A1529'),
        (21, 6, '2015-12-01 05:50:11', '2015-12-01 05:50:11', 'A1526'),
        (22, 6, '2015-12-01 05:50:19', '2015-12-01 05:50:19', 'A1507'),
        (23, 6, '2015-12-01 05:50:28', '2015-12-01 05:50:28', 'A1456'),
        (24, 6, '2015-12-01 05:50:39', '2015-12-01 05:50:39', 'A1532'),
        (25, 7, '2015-12-01 05:52:07', '2015-12-01 05:52:07', 'A1428'),
        (26, 7, '2015-12-01 05:52:18', '2015-12-01 05:52:18', 'A1442'),
        (27, 7, '2015-12-01 05:52:26', '2015-12-01 05:52:26', 'A1429'),
        (28, 8, '2015-12-01 05:53:37', '2015-12-01 05:53:37', 'A1431'),
        (29, 8, '2015-12-01 05:53:48', '2015-12-01 05:53:48', 'A1387'),
        (30, 9, '2015-12-01 05:55:21', '2015-12-01 05:55:21', 'A1574'),
        (31, 10, '2015-12-01 05:55:34', '2015-12-01 05:55:34', 'A1421'),
        (32, 10, '2015-12-01 05:55:45', '2015-12-01 05:55:45', 'A1509'),
        (33, 11, '2015-12-01 05:56:55', '2015-12-01 05:56:55', 'A1367');
      )
      execute(ios_device_models)

      ios_devices = %(
        INSERT INTO `ios_devices` (`id`, `serial_number`, `ip`, `purpose`, `created_at`, `updated_at`, `in_use`, `last_used`, `ios_version`, `description`, `softlayer_proxy_id`, `ios_device_model_id`, `ios_version_fmt`, `disabled`)
        VALUES
        (1, 'CCQPX53QGGK7', '192.168.2.121', 0, '2015-10-26 23:06:38', '2016-08-03 22:52:40', 0, '2016-08-03 22:51:05', '8.4', 'Red Touch', 2, 30, '008.004.000', 0),
        (2, 'CCQN405MG22T', '192.168.2.122', NULL, NULL, '2016-02-13 02:04:37', NULL, '2016-02-13 02:02:36', '9.0.2', 'Blue Touch', NULL, 31, '009.000.002', 1),
        (3, 'F18M9XPJFFDQ', '192.168.2.104', 1, '2015-11-20 04:29:52', '2016-08-15 11:47:31', 0, '2016-08-15 11:45:11', '8.4', 'Gold iPhone', 1, 18, '008.004.000', 0),
        (7, 'CCQPR4FEGGK4', '192.168.2.105', 1, '2015-11-25 09:13:11', '2016-08-15 11:56:44', 0, '2016-08-15 11:55:53', '8.4', 'Blue Touch', 2, 30, '008.004.000', 0),
        (9, 'DNPKQ7L9F8GH', '192.168.2.106', NULL, '2015-11-25 10:23:54', '2015-12-11 01:58:36', NULL, '2015-12-09 23:58:36', '8.4', 'Black iPhone 5', 0, 27, '008.004.000', 1),
        (10, 'F18K87YJF8H4', '192.168.2.107', NULL, '2015-11-29 23:49:45', '2016-07-08 23:53:09', 0, '2016-07-03 07:56:27', '8.4', 'White Phone ( BATTERY BLOAT)', 5, 27, '008.004.000', 1),
        (11, 'C39JL7NADTTN', '192.168.2.108', NULL, '2015-11-30 04:12:08', '2016-08-10 10:49:49', 0, '2016-08-10 10:47:55', '8.4', 'Black Phone (BATTERY BLOAT)', 6, 25, '008.004.000', 1),
        (12, 'C38K5DT4DTTN', '192.168.2.109', 1, '2015-11-30 05:57:19', '2016-08-15 11:49:15', 0, '2016-08-15 11:46:07', '8.4', '', 7, 25, '008.004.000', 0),
        (13, 'F17M9DRMFF9R', '192.168.2.110', 1, '2015-11-30 06:19:38', '2016-08-15 11:48:02', 0, '2016-08-15 11:44:59', '8.4', 'Black Phone', 8, 18, '008.004.000', 0),
        (15, 'F73LP6BTFFHG', '192.168.2.111', 1, '2015-12-04 04:28:02', '2016-08-15 11:47:12', 0, '2016-08-15 11:44:48', '8.4', 'White 5C', 9, 24, '008.004.000', 0),
        (17, 'C38MFG94FF9R', '192.168.2.112', NULL, '2015-12-07 08:33:02', '2015-12-11 01:58:36', NULL, NULL, '9.0.2', 'Black Phone (SIM card problems. Not operational)', 10, 18, '009.000.002', 1),
        (18, 'DNPM9FA6FFDQ', '192.168.2.113', 1, '2015-12-08 09:19:11', '2016-08-15 11:46:44', 0, '2016-08-15 11:44:19', '8.4', 'Gold Phone', 11, 18, '008.004.000', 0),
        (19, 'CCQJV99YF4JR', '192.168.2.114', NULL, '2015-12-09 19:38:16', '2016-02-13 02:04:07', NULL, '2016-02-13 01:57:54', '9.0.2', 'Gold Touch', NULL, 31, '009.000.002', 1),
        (21, 'CCQL95NXF4K4', '192.168.2.115', 0, '2016-01-04 23:25:16', '2016-08-15 22:39:02', 0, '2016-08-15 22:37:21', '9.0.2', 'Black iPod Touch', 3, 31, '009.000.002', 0),
        (22, 'C38L955MFF9R', '192.168.2.116', NULL, '2016-01-05 02:14:41', '2016-04-29 22:49:51', 0, '2016-04-29 22:00:21', '9.0.2', 'Black iPhone', 25, 18, '009.000.002', 1),
        (23, 'DNQKD4TNDTTN', '192.168.2.117', 0, '2016-01-05 02:39:10', '2016-08-15 22:38:55', 0, '2016-08-15 22:37:16', '9.0.2', 'Black iPhone', 15, 25, '009.000.002', 0),
        (24, 'F1GMK2ENFF9R', '192.168.2.118', 1, '2016-01-05 19:07:54', '2016-08-15 11:48:15', 0, '2016-08-15 11:45:59', '8.4', 'Black iPhone', 16, 18, '008.004.000', 0),
        (25, 'C39JQEA9F8H5', '192.168.2.119', 1, '2016-01-05 19:42:37', '2016-08-15 11:46:09', 0, '2016-08-15 11:44:02', '8.3', 'Black iPhone', 17, 27, '008.003.000', 0),
        (26, 'F2LLR2BBFFDR', '192.168.2.120', 0, '2016-01-06 00:46:04', '2016-08-15 22:20:25', 0, '2016-08-15 22:19:07', '8.4', 'Gold iPhone', 18, 17, '008.004.000', 0),
        (27, 'C3RKL1SQFFCJ', '192.168.2.123', NULL, '2016-02-02 01:00:59', '2016-03-10 12:17:24', 0, '2016-03-10 12:15:16', '9.0.2', 'Silver iPod Touch', 19, 32, '009.000.002', 1),
        (28, 'F2LM7DMUFF9R', '192.168.2.124', 1, '2016-02-13 01:25:09', '2016-08-15 11:45:48', 0, '2016-08-15 11:44:03', '8.4', 'Black iPhone', 20, 18, '008.004.000', 0),
        (29, 'C3RKMB0AFFCJ', '192.168.2.125', NULL, '2016-02-13 01:45:14', '2016-03-01 16:56:51', NULL, '2016-03-01 16:43:03', '8.4', 'Black iPod Touch', NULL, 32, '008.004.000', 1),
        (30, 'CCQLX3H0FFCJ', '192.168.2.126', NULL, '2016-02-16 00:21:50', '2016-03-15 17:19:16', 0, '2016-03-15 17:15:58', '8.4', 'Black iPod Touch', 12, 32, '008.004.000', 1),
        (31, 'DNPNCK1WG5MH', '192.168.2.127', 3, '2016-03-09 17:35:05', '2016-08-15 22:00:49', 0, '2016-08-15 22:00:23', '9.0.2', 'White iPhone 6', 28, 12, '009.000.002', 0),
        (32, 'CCQQK3KYGGNL', '192.168.2.128', NULL, '2016-03-12 00:17:39', '2016-03-15 01:30:07', 1, '2016-03-14 03:09:13', '9.0.2', 'Black iPod Touch', NULL, 30, '009.000.002', 1),
        (33, 'FK1NL2FKG5QK', '192.168.2.129', 3, '2016-03-29 21:40:30', '2016-08-15 22:00:28', 0, '2016-08-15 22:00:19', '9.0.2', 'iPhone 6 Plus', 26, 9, '009.000.002', 0),
        (34, 'F18PKCAHG5MF', '192.168.2.130', 3, '2016-04-01 18:33:20', '2016-08-15 22:00:30', 0, '2016-08-15 22:00:22', '9.1', 'Gold iPhone 6', 27, 12, '009.001.000', 0),
        (36, 'FK2QLXNNGRYF', '192.168.2.131', NULL, '2016-04-14 23:29:00', '2016-04-14 23:29:00', NULL, NULL, '9.0.2', 'Rose Gold 6S (bricked)', 4, 5, '009.000.002', 1),
        (37, 'F17QW6WBGRXQ', '192.168.2.132', 3, '2016-04-27 20:33:44', '2016-08-15 22:00:30', 0, '2016-08-15 22:00:22', '9.1', 'Black iPhone 6s', 29, 6, '009.001.000', 0),
        (38, 'F17MQ0CZFFFJ', '192.168.2.133', 1, '2016-05-17 00:22:59', '2016-08-15 11:46:34', 0, '2016-08-15 11:45:39', '8.4', 'Black iPhone 5s', 30, 17, '008.004.000', 0);
      )
      execute(ios_devices)

      service_statuses = %(
        INSERT INTO `service_statuses` (`id`, `service`, `active`, `description`, `outage_message`, `created_at`, `updated_at`)
        VALUES
        (1, 1, 1, 'iOS Facebook ad spend', NULL, '2016-03-13 17:15:59', '2016-05-27 21:45:07'),
        (2, 0, 1, 'iOS Live Scan', NULL, '2016-03-15 20:48:38', '2016-04-06 16:03:49'),
        (3, 2, 1, 'iOS FB Device Cleaning', NULL, '2016-04-06 20:46:31', '2016-05-27 21:45:03'),
        (4, 3, 1, 'iOS international live scans', NULL, '2016-06-29 23:05:53', '2016-08-03 22:50:53');

      )

      execute(service_statuses)

    end

  end

end