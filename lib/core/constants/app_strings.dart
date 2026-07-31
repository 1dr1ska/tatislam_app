/// App-wide string constants
library;
import 'package:flutter/material.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';

class AppStrings {
  AppStrings._();

  // App Info
  static const String appName = 'ТАТИСЛАМ';
  
  // Colored app name parts
  static const String tatPart = 'ТАТ';
  static const String islamPart = 'ИСЛАМ';
  
  // Rich text for colored app name
  static TextSpan getColoredAppName() {
    return TextSpan(
      text: tatPart,
      style: TextStyle(
        color: AppColors.accent, // Red for ТАТ
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      children: [
        TextSpan(
          text: islamPart,
          style: TextStyle(
            color: AppColors.islamGreen, // Green for ИСЛАМ
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Бу каналда Раил Фәйзрахмановның татар телендәге вәгазьләре һәм мәкаләләре урын алган канал.';

  // Navigation Labels
  static const String homeTab = 'Баш бит';
  static const String catalogTab = 'Каталог';
  static const String searchTab = 'Эзләргә';
  static const String favoritesTab = 'Сайланганнар';
  static const String aboutTab = 'ТАТИСЛАМ';

  // Publication Types
  static const String articleType = 'article';
  static const String videoType = 'video';
  static const String audioType = 'audio';

  // UI Strings
  static const String loadMore = 'Загрузить еще';
  static const String noContent = 'Эчтәлек юк';
  static const String noPublications = 'Язмалар юк';
  static const String errorLoading = 'Ошибка загрузки';
  static const String needInternetForFirstLoad =
      'Для первой загрузки приложения требуется подключение к сети';
  static const String retry = 'Повторить';
  static const String loading = 'Загрузка...';
  static const String share = 'Поделиться';
  static const String addToFavorites = 'Сайланганнарга өстәү';
  static const String removeFromFavorites = 'Сайланганнардан бетерү';
  static const String publishedAt = 'Опубликовано: ';
  static const String views = 'Просмотров';
  
  // Home Screen Mode Labels
  static const String feedMode = 'Лента';
  static const String cardsMode = 'Карточки';
}
