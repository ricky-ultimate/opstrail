#[cfg(test)]
mod tests {
    use crate::session::SessionManager;

    #[test]
    fn test_session_ids_are_unique() {
        let id1 = crate::session::SessionManager::generate_session_id_pub();
        let id2 = crate::session::SessionManager::generate_session_id_pub();
        assert_ne!(id1, id2);
    }

    #[test]
    fn test_session_id_is_valid_uuid() {
        let id = SessionManager::generate_session_id_pub();
        assert!(uuid::Uuid::parse_str(&id).is_ok());
    }
}
