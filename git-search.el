
(require 'json)

;;; Code:
(defgroup gh-search nil "Search code in a GitHub repository using the gh CLI."
  :group 'tools)

(defcustom gh-search-repo "" "The GitHub repository to search."
  :type 'string
  :group 'gh-search)


(defcustom gh-search-local-repo-path "" "Local path to the cloned repository.  If set, files will be opened from here."
  :type 'string
  :group 'gh-search)

(defun gh-search (query) "Search QUERY in the GitHub repository specified by `gh-search-repo`." (interactive "sSearch GitHub for: ")
  (let ((buffer-name "*GitHub Search Results*")
         (command (format "gh search code --repo %s --limit 100 --json 'path,textMatches' -- '%s'" gh-search-repo query)))
    (with-current-buffer (get-buffer-create buffer-name)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Results for '%s' in %s:\n\n" query gh-search-repo))
        (let* ((json-output (shell-command-to-string command))
                (results (append (ignore-errors (json-read-from-string json-output)) nil)))
          (if (and results (listp results))
            (progn (if (= (length results) 0)
                     (insert "No results found.\n")
                     (dolist (result results)
                       (let* ((path (cdr (assoc 'path result)))
                               (text-matches (cdr (assoc 'textMatches result)))
                               (fragment (and text-matches (cdr (assoc 'fragment (elt text-matches 0))))))
                         ;; Insert a clickable link
                         (let ((act (lambda (_)
                                      (gh-search-open-file path fragment))))
                           (insert-text-button (format "%s\n" path) 'action act 'follow-link t))
                         ;; Insert code snippet
                         (when fragment (insert (format "%s\n\n" fragment))))))
              (gh-search-mode)
              (goto-char (point-min)))
            ;; Else clause for when results are nil or not a list
            (insert "An error occurred or no results found.\n")
            (insert "Command output:\n" results))))
            (display-buffer buffer-name))))

(defun gh-search-open-file (path fragment) "Open the file at PATH and search for FRAGMENT."
        (if gh-search-local-repo-path
                (let ((full-path (expand-file-name path gh-search-local-repo-path)))
                        (message "DDD>> %s" full-path)
                        (if (file-exists-p full-path)
                                (progn (find-file full-path)
                                        (goto-char (point-min))
                                        (if (search-forward fragment nil t)
                                                (message "Navigated to match.")
                                                (message "Fragment not found in the file.")))
                                (message "File not found locally: %s" full-path)))
                (message "Please set `gh-search-local-repo-path` to open files locally.")))

(define-derived-mode gh-search-mode special-mode "GitHub-Search" "Major mode for displaying GitHub search results." (read-only-mode 1)
  (define-key gh-search-mode-map (kbd "RET") 'gh-search-open-at-point))

(defun gh-search-open-at-point () "Open the file at point." (interactive)
  (let ((pos (point)))
    (when (get-text-property pos 'action)
      (funcall (get-text-property pos 'action) nil))))

(provide 'gh-search)

;;; git-search.el ends here
