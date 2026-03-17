# Display check results. Expects globals: nvm_emoji, nvm_msg, nvm_configured_emoji, nvm_configured_msg,
# nvm_zshhook_emoji, nvm_zshhook_msg, nvm_footer, node_emoji, node_msg, node_footer, npm_emoji, npm_msg, summary_emoji, summary_msg.
display_results() {
  echo ""
  echo "  $nvm_emoji  nvm · installed        $nvm_msg"
  echo "  ${nvm_configured_emoji:-—}  nvm · configured       ${nvm_configured_msg:-(nvm not installed)}"
  echo "  ${nvm_zshhook_emoji:-—}  nvm · auto load config  ${nvm_zshhook_msg:-n/a}"
  echo "  $node_emoji  Node · version         $node_msg"
  echo "  $npm_emoji  Node · npm              $npm_msg"
  echo ""
  echo "  $summary_emoji  Setup and version check $summary_msg"
  if [[ "${node_footer:-0}" -eq 1 || "${nvm_footer:-0}" -eq 1 ]]; then
    echo ""
    echo "  💡  To fix the issues run:  npm run cli -- install"
  fi
  echo ""
}
