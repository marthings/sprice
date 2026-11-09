//
//  NetworkSession.swift
//  Spotprice
//
//  Ephemeral URLSession without HTTP caching for fresh API data

import Foundation

enum NetworkSession {
    nonisolated static let shared: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
}
