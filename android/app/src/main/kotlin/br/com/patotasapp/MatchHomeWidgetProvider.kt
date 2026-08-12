package br.com.patotasapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class MatchHomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val state = widgetData.getString("match_widget_state", "empty") ?: "empty"
            val matchId = widgetData.getString("match_widget_match_id", "") ?: ""
            val groupId = widgetData.getString("match_widget_group_id", "") ?: ""
            val showsScore = state == "live" || state == "score"

            val views = RemoteViews(context.packageName, R.layout.match_home_widget).apply {
                setTextViewText(
                    R.id.match_widget_group,
                    widgetData.getString("match_widget_group_name", "PatotasApp") ?: "PatotasApp",
                )
                setTextViewText(
                    R.id.match_widget_title,
                    widgetData.getString("match_widget_title", "Nenhuma partida agendada")
                        ?: "Nenhuma partida agendada",
                )
                setTextViewText(
                    R.id.match_widget_subtitle,
                    widgetData.getString(
                        "match_widget_subtitle",
                        "Abra o PatotasApp para acompanhar sua patota.",
                    ) ?: "Abra o PatotasApp para acompanhar sua patota.",
                )
                setTextViewText(
                    R.id.match_widget_response,
                    widgetData.getString("match_widget_response", "Aguardando sua resposta")
                        ?: "Aguardando sua resposta",
                )
                setTextViewText(
                    R.id.match_widget_confirmed,
                    widgetData.getString("match_widget_confirmed", "0 confirmados")
                        ?: "0 confirmados",
                )
                setTextViewText(
                    R.id.match_widget_team_a,
                    widgetData.getString("match_widget_team_a", "Time A") ?: "Time A",
                )
                setTextViewText(
                    R.id.match_widget_team_b,
                    widgetData.getString("match_widget_team_b", "Time B") ?: "Time B",
                )
                setTextViewText(
                    R.id.match_widget_score_a,
                    widgetData.getString("match_widget_score_a", "0") ?: "0",
                )
                setTextViewText(
                    R.id.match_widget_score_b,
                    widgetData.getString("match_widget_score_b", "0") ?: "0",
                )

                setTextColor(
                    R.id.match_widget_team_a,
                    parseColor(widgetData.getString("match_widget_team_a_color", null), "#3CB043"),
                )
                setTextColor(
                    R.id.match_widget_team_b,
                    parseColor(widgetData.getString("match_widget_team_b_color", null), "#D64545"),
                )

                setViewVisibility(
                    R.id.match_widget_live_badge,
                    if (state == "live") View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.match_widget_score,
                    if (showsScore) View.VISIBLE else View.GONE,
                )
                setViewVisibility(
                    R.id.match_widget_upcoming,
                    if (showsScore) View.GONE else View.VISIBLE,
                )

                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = if (matchId.isNotBlank()) {
                        Uri.parse(
                            "patotasapp://open/app/matches?matchId=${Uri.encode(matchId)}" +
                                "&groupId=${Uri.encode(groupId)}",
                        )
                    } else {
                        Uri.parse("patotasapp://open/app")
                    }
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.match_widget_root, pendingIntent)
                setOnClickPendingIntent(R.id.match_widget_open_button, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun parseColor(value: String?, fallback: String): Int = try {
        Color.parseColor(value ?: fallback)
    } catch (_: IllegalArgumentException) {
        Color.parseColor(fallback)
    }
}
