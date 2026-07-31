import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_requests.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/role_theme.dart';
import '../../widgets/request_card.dart';

class RequestsFeedScreen extends StatelessWidget {
  const RequestsFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final requests = mockRequests();
    final driverTheme = roleThemeFor(UiRole.driver);

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: driverTheme.headerGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl4)),
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('requests.page_title'.tr(),
                  style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 14, 16, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => RequestCard(
                request: requests[i],
                onTap: () => context.push('/requests/${requests[i].id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
